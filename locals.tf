# ============================================
# PROFILES -> SETTINGS
# ============================================
# Every tunable lives here once. `var.overrides` is merged on top, so any key can be changed
# without forking the module. The resolved map is exposed as the `settings` output.

locals {
  profiles = {
    starter = {
      az_count               = 2
      nat_mode               = "single" # none | single | per_az
      interface_endpoints    = false
      flow_log_retention     = 14
      log_retention          = 30
      audit_log_retention    = 90
      kms_cmk                = false
      waf                    = false
      waf_rate_limit         = 2000
      waf_blocked_countries  = []
      guardduty              = true
      inspector              = false
      security_hub           = false
      aws_config             = false
      cloudtrail             = true
      cis_alarms             = false
      access_analyzer        = true
      ebs_default_encryption = true
      backup                 = false
      backup_daily_days      = 0
      backup_weekly_days     = 0
      backup_vault_lock      = false
      alb_deletion_protect   = false
      require_https          = false
      rds_instance_class     = "db.t4g.micro"
      rds_storage_gb         = 20
      rds_max_storage_gb     = 100
      rds_multi_az           = false
      rds_deletion_protect   = false
      rds_backup_days        = 1
      rds_skip_final_snap    = true
      rds_perf_insights      = false
      redis_node_type        = "cache.t4g.micro"
      redis_nodes            = 1
      redis_snapshot_days    = 0
      ecs_capacity           = "FARGATE_SPOT"
      ecs_container_insights = false
      ecs_exec               = true
      ecr_immutable_tags     = false
      eks_public_endpoint    = true
      efs_throughput         = "elastic"
    }

    production = {
      az_count               = 2
      nat_mode               = "per_az"
      interface_endpoints    = false
      flow_log_retention     = 90
      log_retention          = 90
      audit_log_retention    = 365
      kms_cmk                = false
      waf                    = true
      waf_rate_limit         = 2000
      waf_blocked_countries  = []
      guardduty              = true
      inspector              = true
      security_hub           = true
      aws_config             = true
      cloudtrail             = true
      cis_alarms             = true
      access_analyzer        = true
      ebs_default_encryption = true
      backup                 = true
      backup_daily_days      = 35
      backup_weekly_days     = 365
      backup_vault_lock      = false
      alb_deletion_protect   = true
      require_https          = true
      rds_instance_class     = "db.t4g.medium"
      rds_storage_gb         = 50
      rds_max_storage_gb     = 500
      rds_multi_az           = true
      rds_deletion_protect   = true
      rds_backup_days        = 7
      rds_skip_final_snap    = false
      rds_perf_insights      = false
      redis_node_type        = "cache.t4g.small"
      redis_nodes            = 2
      redis_snapshot_days    = 7
      ecs_capacity           = "FARGATE"
      ecs_container_insights = true
      ecs_exec               = true
      ecr_immutable_tags     = false
      eks_public_endpoint    = false
      efs_throughput         = "elastic"
    }

    regulated = {
      az_count               = 3
      nat_mode               = "per_az"
      interface_endpoints    = true
      flow_log_retention     = 365
      log_retention          = 365
      audit_log_retention    = 2557 # 7 years
      kms_cmk                = true
      waf                    = true
      waf_rate_limit         = 1000
      waf_blocked_countries  = []
      guardduty              = true
      inspector              = true
      security_hub           = true
      aws_config             = true
      cloudtrail             = true
      cis_alarms             = true
      access_analyzer        = true
      ebs_default_encryption = true
      backup                 = true
      backup_daily_days      = 90
      backup_weekly_days     = 2557
      backup_vault_lock      = true
      alb_deletion_protect   = true
      require_https          = true
      rds_instance_class     = "db.m7g.large"
      rds_storage_gb         = 100
      rds_max_storage_gb     = 1000
      rds_multi_az           = true
      rds_deletion_protect   = true
      rds_backup_days        = 35
      rds_skip_final_snap    = false
      rds_perf_insights      = true
      redis_node_type        = "cache.m7g.large"
      redis_nodes            = 2
      redis_snapshot_days    = 35
      ecs_capacity           = "FARGATE"
      ecs_container_insights = true
      ecs_exec               = false
      ecr_immutable_tags     = true
      eks_public_endpoint    = false
      efs_throughput         = "elastic"
    }
  }

  s = merge(local.profiles[var.profile], var.overrides)
}

# ============================================
# NAMING, TAGS, STACK FLAGS
# ============================================
locals {
  prefix     = "${var.name}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  tags = merge({
    Project     = var.name
    Environment = var.environment
    Profile     = var.profile
    ManagedBy   = "terraform"
    Module      = "aws-platform"
  }, var.tags)

  has = {
    ecs   = contains(var.stack, "ecs")
    eks   = contains(var.stack, "eks")
    rds   = contains(var.stack, "rds")
    redis = contains(var.stack, "redis")
    efs   = contains(var.stack, "efs")
    cdn   = contains(var.stack, "cdn")
    # Also require their inputs, so a missing block surfaces as the guardrail message, not a null error.
    vpn             = contains(var.stack, "vpn") && var.vpn != null
    client_vpn      = contains(var.stack, "client-vpn") && var.client_vpn != null
    transit_gateway = contains(var.stack, "transit-gateway")
  }

  # Account-level singletons are only managed when account_baseline = true.
  baseline = {
    guardduty       = var.account_baseline && local.s.guardduty
    inspector       = var.account_baseline && local.s.inspector
    security_hub    = var.account_baseline && local.s.security_hub
    aws_config      = var.account_baseline && local.s.aws_config
    cloudtrail      = var.account_baseline && local.s.cloudtrail
    cis_alarms      = var.account_baseline && local.s.cloudtrail && local.s.cis_alarms
    access_analyzer = var.account_baseline && local.s.access_analyzer
    ebs_encryption  = var.account_baseline && local.s.ebs_default_encryption
  }

  kms_key_arn = local.s.kms_cmk ? aws_kms_key.platform[0].arn : null

  # HTTPS: bring-your-own cert, or issue one when a hosted zone is given.
  issue_certificate = var.domain != null && try(var.domain.certificate_arn, null) == null && try(var.domain.zone_id, null) != null
  certificate_arn = (
    var.domain == null ? null :
    try(var.domain.certificate_arn, null) != null ? var.domain.certificate_arn :
    local.issue_certificate ? aws_acm_certificate_validation.alb[0].certificate_arn : null
  )
  # Decided from inputs (known at plan time), never from the issued certificate's ARN.
  https = var.domain != null && (try(var.domain.certificate_arn, null) != null || try(var.domain.zone_id, null) != null)
}

# ============================================
# NETWORK MATH
# ============================================
locals {
  az_count = coalesce(try(var.network.az_count, null), local.s.az_count)
  azs      = slice(data.aws_availability_zones.available.names, 0, local.az_count)
  vpc_cidr = var.network.cidr

  public_subnets  = [for i in range(local.az_count) : cidrsubnet(local.vpc_cidr, var.network.subnet_newbits, i)]
  private_subnets = [for i in range(local.az_count) : cidrsubnet(local.vpc_cidr, var.network.subnet_newbits, i + 8)]
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
