# ============================================
# ECS ON FARGATE  (stack includes "ecs")
# ============================================

resource "aws_ecs_cluster" "main" {
  count = local.has.ecs ? 1 : 0
  name  = local.prefix

  setting {
    name  = "containerInsights"
    value = local.s.ecs_container_insights ? "enabled" : "disabled"
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  count              = local.has.ecs ? 1 : 0
  cluster_name       = aws_ecs_cluster.main[0].name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = local.s.ecs_capacity
    weight            = 1
  }
}

resource "aws_ecr_repository" "service" {
  for_each = local.services

  name                 = "${local.prefix}/${each.key}"
  image_tag_mutability = local.s.ecr_immutable_tags ? "IMMUTABLE" : "MUTABLE"
  force_delete         = !local.s.rds_deletion_protect # starter can be torn down cleanly

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = local.s.kms_cmk ? "KMS" : "AES256"
    kms_key         = local.kms_key_arn
  }

  tags = merge(local.tags, { Service = each.key })
}

resource "aws_ecr_lifecycle_policy" "service" {
  for_each   = aws_ecr_repository.service
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 7 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the 30 most recent images"
        selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 30 }
        action       = { type = "expire" }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "service" {
  for_each          = local.services
  name              = "/ecs/${local.prefix}/${each.key}"
  retention_in_days = local.s.log_retention
  kms_key_id        = local.kms_key_arn
  tags              = merge(local.tags, { Service = each.key })
}

# --------------------------------------------
# Auto-wiring: connection details for whatever is in the stack
# --------------------------------------------
locals {
  wired_env = merge(
    local.has.rds ? {
      DB_ENGINE = var.database.engine
      DB_HOST   = module.rds[0].address
      DB_PORT   = tostring(module.rds[0].port)
      DB_NAME   = module.rds[0].db_name
    } : {},
    local.has.redis ? {
      REDIS_HOST = module.redis[0].primary_endpoint
      REDIS_PORT = "6379"
      REDIS_TLS  = "true"
    } : {},
    { for k, b in module.app_bucket : "BUCKET_${upper(replace(k, "-", "_"))}" => b.bucket_id },
    {
      APP_NAME        = var.name
      APP_ENVIRONMENT = var.environment
      AWS_REGION      = local.region
    }
  )

  wired_secrets = merge(
    local.has.rds ? {
      DB_USERNAME = "${module.rds[0].master_user_secret_arn}:username::"
      DB_PASSWORD = "${module.rds[0].master_user_secret_arn}:password::"
    } : {},
    local.has.redis ? {
      REDIS_AUTH_TOKEN = module.redis[0].auth_secret_arn
    } : {}
  )

  app_bucket_arns = [for b in module.app_bucket : b.bucket_arn]

  task_policy = length(local.app_bucket_arns) > 0 || local.s.kms_cmk ? jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [for x in [
        {
          Sid      = "AppBucketsList"
          Effect   = "Allow"
          Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
          Resource = local.app_bucket_arns
        },
        {
          Sid      = "AppBucketsObjects"
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"]
          Resource = [for a in local.app_bucket_arns : "${a}/*"]
        }
      ] : x if length(local.app_bucket_arns) > 0],
      local.s.kms_cmk ? [{
        Sid      = "PlatformKeyForAppData"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = local.kms_key_arn
      }] : []
    )
  }) : null
}

module "ecs_service" {
  source   = "./modules/ecs_service"
  for_each = local.services

  name           = "${local.prefix}-${each.key}"
  cluster_id     = aws_ecs_cluster.main[0].id
  cluster_name   = aws_ecs_cluster.main[0].name
  container_name = each.key
  image          = coalesce(each.value.image, "${aws_ecr_repository.service[each.key].repository_url}:latest")
  port           = each.value.port
  cpu            = each.value.cpu
  memory         = each.value.memory
  desired_count  = each.value.desired_count
  min_count      = each.value.min_count
  max_count      = each.value.max_count

  # User-supplied values win over auto-wired ones.
  environment = merge(local.wired_env, each.value.environment)
  secrets     = merge(local.wired_secrets, each.value.secrets)
  kms_key_arn = local.kms_key_arn

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.tasks_security_group_id]
  target_group_arn   = aws_lb_target_group.service[each.key].arn
  log_group_name     = aws_cloudwatch_log_group.service[each.key].name
  capacity_provider  = local.s.ecs_capacity
  enable_exec        = local.s.ecs_exec
  task_policy_json   = local.task_policy
  deployed_by_ci     = coalesce(each.value.deployed_by_ci, var.github_repository != "")

  efs = each.value.efs_mount_path != null && local.has.efs ? {
    file_system_id   = aws_efs_file_system.shared[0].id
    file_system_arn  = aws_efs_file_system.shared[0].arn
    access_point_id  = aws_efs_access_point.shared[0].id
    access_point_arn = aws_efs_access_point.shared[0].arn
    mount_path       = each.value.efs_mount_path
  } : null

  tags = merge(local.tags, { Service = each.key })

  depends_on = [aws_lb_listener.http, aws_lb_listener.https, aws_lb_listener_rule.service, aws_ecs_cluster_capacity_providers.main]
}
