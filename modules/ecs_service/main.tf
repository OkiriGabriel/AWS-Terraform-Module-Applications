locals {
  efs_enabled = var.efs != null
  service     = one(concat(aws_ecs_service.main, aws_ecs_service.ci_managed))

  # "arn:...:secret:name-AbCdEf:jsonKey::" -> "arn:...:secret:name-AbCdEf"
  secret_arns_sm  = distinct([for v in values(var.secrets) : regex("^arn:[^:]+:secretsmanager:[^:]+:[^:]+:secret:[^:]+", v) if can(regex("^arn:[^:]+:secretsmanager:[^:]+:[^:]+:secret:[^:]+", v))])
  secret_arns_ssm = distinct([for v in values(var.secrets) : v if can(regex("^arn:[^:]+:ssm:", v))])
}

resource "aws_ecs_task_definition" "main" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  dynamic "volume" {
    for_each = local.efs_enabled ? [1] : []
    content {
      name = "efs"
      efs_volume_configuration {
        file_system_id     = var.efs.file_system_id
        transit_encryption = "ENABLED"
        authorization_config {
          access_point_id = var.efs.access_point_id
          iam             = "ENABLED"
        }
      }
    }
  }

  container_definitions = jsonencode([
    merge({
      name      = var.container_name
      image     = var.image
      essential = true

      portMappings = [{
        name          = var.container_name
        containerPort = var.port
        protocol      = "tcp"
        appProtocol   = "http"
      }]

      environment = [for k, v in var.environment : { name = k, value = v }]
      secrets     = [for k, v in var.secrets : { name = k, valueFrom = v }]

      mountPoints = local.efs_enabled ? [{
        sourceVolume  = "efs"
        containerPath = var.efs.mount_path
        readOnly      = false
      }] : []

      readonlyRootFilesystem = var.readonly_root_filesystem

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = var.container_name
        }
      }
      },
      # ECS Exec needs an init process to reap the SSM agent's child processes.
      var.enable_exec ? { linuxParameters = { initProcessEnabled = true } } : {}
    )
  ])

  tags = var.tags
}

# Terraform rolls out every task-definition change.
resource "aws_ecs_service" "main" {
  count                   = var.deployed_by_ci ? 0 : 1
  name                    = var.name
  cluster                 = var.cluster_id
  task_definition         = aws_ecs_task_definition.main.arn
  desired_count           = var.desired_count
  enable_execute_command  = var.enable_exec
  propagate_tags          = "SERVICE"
  enable_ecs_managed_tags = true

  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider
    weight            = 1
  }

  # Roll back automatically when a new task definition fails to reach steady state.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container_name
    container_port   = var.port
  }

  lifecycle {
    ignore_changes = [desired_count] # autoscaling owns the count
  }

  tags = var.tags
}

# CI rolls out images; Terraform still manages the task definition, roles, env and secrets.
resource "aws_ecs_service" "ci_managed" {
  count                   = var.deployed_by_ci ? 1 : 0
  name                    = var.name
  cluster                 = var.cluster_id
  task_definition         = aws_ecs_task_definition.main.arn
  desired_count           = var.desired_count
  enable_execute_command  = var.enable_exec
  propagate_tags          = "SERVICE"
  enable_ecs_managed_tags = true

  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider
    weight            = 1
  }

  # Roll back automatically when a new task definition fails to reach steady state.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container_name
    container_port   = var.port
  }

  # CI owns which revision runs (it deploys from the latest revision Terraform registered).
  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  tags = var.tags
}

# --------------------------------------------
# Autoscaling (CPU + memory target tracking)
# --------------------------------------------
resource "aws_appautoscaling_target" "main" {
  min_capacity       = var.min_count
  max_capacity       = var.max_count
  resource_id        = "service/${var.cluster_name}/${local.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main.resource_id
  scalable_dimension = aws_appautoscaling_target.main.scalable_dimension
  service_namespace  = aws_appautoscaling_target.main.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70
  }
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.name}-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main.resource_id
  scalable_dimension = aws_appautoscaling_target.main.scalable_dimension
  service_namespace  = aws_appautoscaling_target.main.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 75
  }
}

# --------------------------------------------
# IAM
# --------------------------------------------
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Read exactly the secrets this service references, nothing else.
resource "aws_iam_role_policy" "execution_secrets" {
  count = length(var.secrets) > 0 ? 1 : 0
  name  = "read-referenced-secrets"
  role  = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      length(local.secret_arns_sm) > 0 ? [{
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = [for a in local.secret_arns_sm : "${a}*"]
      }] : [],
      length(local.secret_arns_ssm) > 0 ? [{
        Effect   = "Allow"
        Action   = "ssm:GetParameters"
        Resource = local.secret_arns_ssm
      }] : [],
      var.kms_key_arn != null ? [{
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = var.kms_key_arn
      }] : []
    )
  })
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "task_exec" {
  count = var.enable_exec ? 1 : 0
  name  = "ecs-exec"
  role  = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "task_efs" {
  count = local.efs_enabled ? 1 : 0
  name  = "efs-mount"
  role  = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
      Resource = var.efs.file_system_arn
      Condition = {
        StringEquals = { "elasticfilesystem:AccessPointArn" = var.efs.access_point_arn }
      }
    }]
  })
}

resource "aws_iam_role_policy" "task_extra" {
  count  = var.task_policy_json != null ? 1 : 0
  name   = "app-permissions"
  role   = aws_iam_role.task.id
  policy = var.task_policy_json
}

data "aws_region" "current" {}
data "aws_partition" "current" {}
