# ============================================
# PLATFORM KMS KEY (kms_cmk = true, default in "regulated")
# ============================================
# One customer-managed key for data at rest: RDS, Redis, EFS, S3, Secrets Manager, ECR, CloudWatch Logs,
# SNS, AWS Backup. Services use it through IAM (kms:ViaService) grants; CloudWatch Logs and SNS need
# explicit key-policy statements, added below.

resource "aws_kms_key" "platform" {
  count                   = local.s.kms_cmk ? 1 : 0
  description             = "${local.prefix} platform data key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${local.region}.amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
        Condition = {
          ArnLike = { "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${local.region}:${local.account_id}:log-group:*" }
        }
      },
      {
        Sid       = "AlarmsAndEventsPublishToEncryptedSNS"
        Effect    = "Allow"
        Principal = { Service = ["cloudwatch.amazonaws.com", "events.amazonaws.com"] }
        Action    = ["kms:Decrypt", "kms:GenerateDataKey*"]
        Resource  = "*"
      }
    ]
  })

  tags = merge(local.tags, { Name = "${local.prefix}-platform" })
}

resource "aws_kms_alias" "platform" {
  count         = local.s.kms_cmk ? 1 : 0
  name          = "alias/${local.prefix}-platform"
  target_key_id = aws_kms_key.platform[0].key_id
}
