# ============================================
# AWS BACKUP  (profile: production, regulated)
# ============================================
# Selects resources by tag, so anything this module creates with local.backup_tags is covered
# automatically (RDS, EFS). Tag your own resources with "<name>-<env>-backup" = "true" to opt in.

resource "aws_backup_vault" "main" {
  count       = local.s.backup ? 1 : 0
  name        = "${local.prefix}-vault"
  kms_key_arn = local.kms_key_arn
  tags        = local.tags
}

# Governance-mode lock: recovery points cannot be deleted early, even by admins, without lock removal.
resource "aws_backup_vault_lock_configuration" "main" {
  count              = local.s.backup && local.s.backup_vault_lock ? 1 : 0
  backup_vault_name  = aws_backup_vault.main[0].name
  min_retention_days = 7
  max_retention_days = max(local.s.backup_weekly_days, local.s.backup_daily_days)
}

resource "aws_backup_plan" "main" {
  count = local.s.backup ? 1 : 0
  name  = "${local.prefix}-plan"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.main[0].name
    schedule          = "cron(0 3 ? * * *)"
    start_window      = 60
    completion_window = 360

    lifecycle {
      delete_after = local.s.backup_daily_days
    }

    recovery_point_tags = merge(local.tags, { BackupType = "daily" })
  }

  dynamic "rule" {
    for_each = local.s.backup_weekly_days > 0 ? [1] : []
    content {
      rule_name         = "weekly"
      target_vault_name = aws_backup_vault.main[0].name
      schedule          = "cron(0 4 ? * SUN *)"
      start_window      = 60
      completion_window = 600

      lifecycle {
        cold_storage_after = 30
        delete_after       = max(local.s.backup_weekly_days, 120)
      }

      recovery_point_tags = merge(local.tags, { BackupType = "weekly" })
    }
  }

  tags = local.tags
}

resource "aws_iam_role" "backup" {
  count = local.s.backup ? 1 : 0
  name  = "${local.prefix}-backup"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  for_each = local.s.backup ? toset(["AWSBackupServiceRolePolicyForBackup", "AWSBackupServiceRolePolicyForRestores"]) : toset([])

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/${each.key}"
}

resource "aws_backup_selection" "tagged" {
  count        = local.s.backup ? 1 : 0
  name         = "${local.prefix}-tagged"
  plan_id      = aws_backup_plan.main[0].id
  iam_role_arn = aws_iam_role.backup[0].arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = keys(local.backup_tag)[0]
    value = "true"
  }
}
