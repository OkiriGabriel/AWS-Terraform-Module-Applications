# Disaster Recovery and Backup Configuration
# Automated backups, cross-AZ replication, and DR procedures

# AWS Backup Vault
resource "aws_backup_vault" "example" {
  name        = "${local.environment}-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn

  tags = merge(local.tags, {
    Purpose = "Centralized backup storage"
  })
}

# KMS Key for Backup Encryption
resource "aws_kms_key" "backup" {
  description             = "KMS key for boiler-plate backups"
  deletion_window_in_days = 7

  tags = merge(local.tags, {
    Purpose = "Backup encryption"
  })
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${local.environment}-boiler-plate-backup"
  target_key_id = aws_kms_key.backup.key_id
}

# Backup Plan
resource "aws_backup_plan" "example" {
  name = "${local.environment}-backup-plan"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.example.name
    schedule          = "cron(0 2 ? * * *)" # 2 AM daily

    start_window      = 60  # 1 hour
    completion_window = 300 # 5 hours

    lifecycle {
      cold_storage_after = 30
      delete_after       = 120 # Must be at least 90 days after cold_storage_after
    }

    recovery_point_tags = merge(local.tags, {
      BackupType = "Daily"
    })
  }

  rule {
    rule_name         = "weekly_backup"
    target_vault_name = aws_backup_vault.example.name
    schedule          = "cron(0 1 ? * SUN *)" # 1 AM every Sunday

    start_window      = 60
    completion_window = 300

    lifecycle {
      cold_storage_after = 30
      delete_after       = 365 # 1 year retention
    }

    recovery_point_tags = merge(local.tags, {
      BackupType = "Weekly"
    })
  }

  tags = local.tags
}

# Backup Selection
resource "aws_backup_selection" "example" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${local.environment}-backup-selection"
  plan_id      = aws_backup_plan.example.id

  resources = [
    try(aws_efs_file_system.wordpress[0].arn, ""),
    "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:db:${local.environment}-db"
  ]
}

# IAM Role for Backup
resource "aws_iam_role" "backup" {
  name = "${local.environment}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# Backup Service Role Policy
resource "aws_iam_role_policy_attachment" "backup_service_role" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_service_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# S3 Cross-Region Replication for DR
resource "aws_s3_bucket_replication_configuration" "example_dr" {
  count = terraform.workspace == "infrastructure-prod" ? 1 : 0

  role   = aws_iam_role.s3_replication[0].arn
  bucket = module.s3_backups.bucket_id

  rule {
    id     = "replicate_backups"
    status = "Enabled"

    destination {
      bucket        = "arn:aws:s3:::${module.s3_backups.bucket_id}-dr-eu-central-1"
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.backup.arn
      }
    }
  }

  # depends_on = [aws_s3_bucket_versioning.example_backups]  # Not needed with S3 module
}

# IAM Role for S3 Replication
resource "aws_iam_role" "s3_replication" {
  count = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name  = "${local.environment}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# S3 Replication Policy
resource "aws_iam_role_policy" "s3_replication" {
  count = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name  = "${local.environment}-s3-replication-policy"
  role  = aws_iam_role.s3_replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl"
        ]
        Resource = "${module.s3_backups.bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = module.s3_backups.bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = "arn:aws:s3:::${module.s3_backups.bucket_id}-dr-eu-central-1/*"
      }
    ]
  })
}

# CloudWatch Alarms for DR Monitoring
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${local.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = "${local.environment}-db"
  }

  tags = local.tags
}

# SNS Topic for DR Alerts
resource "aws_sns_topic" "alerts" {
  name = "${local.environment}-dr-alerts"

  tags = local.tags
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}