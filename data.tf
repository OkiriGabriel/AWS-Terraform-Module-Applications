# ============================================
# DATA STORES: RDS, REDIS, EFS, S3
# ============================================

locals {
  backup_tag  = { "${local.prefix}-backup" = "true" } # AWS Backup selects resources by this tag
  backup_tags = local.s.backup ? local.backup_tag : {}

  # Who may reach the data tier: app tasks, EKS nodes, and Client VPN users (for admin access).
  # Static keys so for_each never depends on IDs that only exist after apply.
  data_clients = merge(
    { tasks = module.security_groups.tasks_security_group_id },
    local.has.eks ? { eks_nodes = module.eks[0].node_security_group_id } : {},
    local.has.client_vpn ? { client_vpn = aws_security_group.client_vpn[0].id } : {},
  )
}

module "rds" {
  source = "./modules/rds"
  count  = local.has.rds ? 1 : 0

  name                    = local.prefix
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  allowed_security_groups = local.data_clients

  engine         = var.database.engine
  engine_version = var.database.engine_version
  db_name        = var.database.name
  parameters     = var.database.parameters

  instance_class               = local.s.rds_instance_class
  allocated_storage            = local.s.rds_storage_gb
  max_allocated_storage        = local.s.rds_max_storage_gb
  multi_az                     = local.s.rds_multi_az
  backup_retention_period      = local.s.rds_backup_days
  deletion_protection          = local.s.rds_deletion_protect
  skip_final_snapshot          = local.s.rds_skip_final_snap
  performance_insights_enabled = local.s.rds_perf_insights
  kms_key_arn                  = local.kms_key_arn

  backup_tags = local.backup_tags
  tags        = local.tags
}

module "redis" {
  source = "./modules/elasticache"
  count  = local.has.redis ? 1 : 0

  name                    = local.prefix
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  allowed_security_groups = local.data_clients

  node_type               = local.s.redis_node_type
  num_nodes               = local.s.redis_nodes
  snapshot_retention_days = local.s.redis_snapshot_days
  kms_key_arn             = local.kms_key_arn

  tags = local.tags
}

# --------------------------------------------
# EFS shared file system
# --------------------------------------------
resource "aws_efs_file_system" "shared" {
  count            = local.has.efs ? 1 : 0
  creation_token   = "${local.prefix}-shared"
  encrypted        = true
  kms_key_id       = local.kms_key_arn
  performance_mode = "generalPurpose"
  throughput_mode  = local.s.efs_throughput

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = merge(local.tags, local.backup_tags, { Name = "${local.prefix}-shared" })
}

resource "aws_efs_file_system_policy" "shared" {
  count          = local.has.efs ? 1 : 0
  file_system_id = aws_efs_file_system.shared[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = { AWS = "*" }
        Action    = "*"
        Resource  = aws_efs_file_system.shared[0].arn
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "MountThroughAccessPointOnly"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
        Resource  = aws_efs_file_system.shared[0].arn
        Condition = {
          StringEquals = { "elasticfilesystem:AccessPointArn" = aws_efs_access_point.shared[0].arn }
          Bool         = { "elasticfilesystem:AccessedViaMountTarget" = "true" }
        }
      }
    ]
  })
}

resource "aws_security_group" "efs" {
  count       = local.has.efs ? 1 : 0
  name        = "${local.prefix}-efs"
  description = "EFS mount targets"
  vpc_id      = module.vpc.vpc_id
  tags        = merge(local.tags, { Name = "${local.prefix}-efs" })
}

resource "aws_vpc_security_group_ingress_rule" "efs" {
  for_each = local.has.efs ? local.data_clients : {}

  security_group_id            = aws_security_group.efs[0].id
  description                  = "NFS clients"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = each.value
}

resource "aws_efs_mount_target" "shared" {
  count           = local.has.efs ? local.az_count : 0
  file_system_id  = aws_efs_file_system.shared[0].id
  subnet_id       = module.vpc.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs[0].id]
}

resource "aws_efs_access_point" "shared" {
  count          = local.has.efs ? 1 : 0
  file_system_id = aws_efs_file_system.shared[0].id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/app"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0750"
    }
  }

  tags = merge(local.tags, { Name = "${local.prefix}-shared-app" })
}

# --------------------------------------------
# Application buckets (TLS-only, ACLs disabled, versioned, KMS in regulated)
# --------------------------------------------
module "app_bucket" {
  source   = "./modules/s3"
  for_each = var.buckets

  bucket_name        = "${local.prefix}-${each.key}-${local.account_id}"
  environment        = var.environment
  versioning         = each.value.versioning
  public_read_access = false
  kms_key_arn        = local.kms_key_arn

  tags = merge(local.tags, { Bucket = each.key })
}

# --------------------------------------------
# CDN: CloudFront + private static bucket (stack includes "cdn")
# --------------------------------------------
module "static_bucket" {
  source = "./modules/s3"
  count  = local.has.cdn ? 1 : 0

  bucket_name        = "${local.prefix}-static-${local.account_id}"
  environment        = var.environment
  versioning         = true
  public_read_access = false
  enforce_tls        = false # the CloudFront module owns this bucket's policy (and denies non-TLS itself)

  tags = merge(local.tags, { Bucket = "static" })
}

module "cdn" {
  source = "./modules/cloudfront_static"
  count  = local.has.cdn ? 1 : 0

  environment  = var.environment
  project_name = var.name

  s3_bucket_id                   = module.static_bucket[0].bucket_id
  s3_bucket_arn                  = module.static_bucket[0].bucket_arn
  s3_bucket_regional_domain_name = module.static_bucket[0].bucket_regional_domain_name

  tags = local.tags
}
