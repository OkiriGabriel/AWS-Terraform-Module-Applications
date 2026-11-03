# ============================================
# ACCOUNT SECURITY BASELINE
# ============================================
# Driven by the profile; only managed when var.account_baseline = true (account/region singletons).

locals {
  alert_emails = var.alert_email != "" ? [var.alert_email] : []
}

# --------------------------------------------
# Threat detection and vulnerability scanning
# --------------------------------------------
module "guardduty" {
  source = "./modules/guardduty"
  count  = local.baseline.guardduty ? 1 : 0

  name_prefix                  = local.prefix
  enable_s3_protection         = true
  enable_kubernetes_protection = local.has.eks
  enable_malware_protection    = true

  enable_notifications   = length(local.alert_emails) > 0
  notification_emails    = local.alert_emails
  minimum_severity_level = 4.0
  enable_findings_export = true
  log_retention_days     = local.s.log_retention

  tags = local.tags
}

resource "aws_guardduty_detector_feature" "rds_login_events" {
  count       = local.baseline.guardduty && local.has.rds ? 1 : 0
  detector_id = module.guardduty[0].detector_id
  name        = "RDS_LOGIN_EVENTS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "runtime_monitoring" {
  count       = local.baseline.guardduty && var.profile != "starter" && (local.has.ecs || local.has.eks) ? 1 : 0
  detector_id = module.guardduty[0].detector_id
  name        = "RUNTIME_MONITORING"
  status      = "ENABLED"

  additional_configuration {
    name   = "ECS_FARGATE_AGENT_MANAGEMENT"
    status = local.has.ecs ? "ENABLED" : "DISABLED"
  }

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = local.has.eks ? "ENABLED" : "DISABLED"
  }
}

module "inspector" {
  source = "./modules/inspector"
  count  = local.baseline.inspector ? 1 : 0

  name_prefix          = local.prefix
  resource_types       = ["EC2", "ECR", "LAMBDA"]
  enable_notifications = length(local.alert_emails) > 0
  notification_emails  = local.alert_emails
  log_retention_days   = local.s.log_retention

  tags = local.tags
}

# --------------------------------------------
# Security Hub + standards
# --------------------------------------------
resource "aws_securityhub_account" "main" {
  count                    = local.baseline.security_hub ? 1 : 0
  enable_default_standards = false
  auto_enable_controls     = true
}

resource "aws_securityhub_standards_subscription" "main" {
  for_each = local.baseline.security_hub ? {
    fsbp   = "arn:${data.aws_partition.current.partition}:securityhub:${local.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
    cis_v3 = "arn:${data.aws_partition.current.partition}:securityhub:${local.region}::standards/cis-aws-foundations-benchmark/v/3.0.0"
  } : {}

  standards_arn = each.value
  depends_on    = [aws_securityhub_account.main]
}

# --------------------------------------------
# AWS Config
# --------------------------------------------
module "config_bucket" {
  source = "./modules/s3"
  count  = local.baseline.aws_config ? 1 : 0

  bucket_name = "${local.prefix}-config-${local.account_id}"
  environment = var.environment
  versioning  = true
  kms_key_arn = local.kms_key_arn

  additional_policy_statements = [
    {
      Sid       = "AWSConfigBucketPermissionsCheck"
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = ["s3:GetBucketAcl", "s3:ListBucket"]
      Resource  = "arn:${data.aws_partition.current.partition}:s3:::${local.prefix}-config-${local.account_id}"
      Condition = { StringEquals = { "aws:SourceAccount" = local.account_id } }
    },
    {
      Sid       = "AWSConfigBucketDelivery"
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "arn:${data.aws_partition.current.partition}:s3:::${local.prefix}-config-${local.account_id}/AWSLogs/${local.account_id}/*"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = local.account_id
          "s3:x-amz-acl"      = "bucket-owner-full-control"
        }
      }
    }
  ]

  tags = local.tags
}

resource "aws_iam_role" "config" {
  count = local.baseline.aws_config ? 1 : 0
  name  = "${local.prefix}-config"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = local.account_id } }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = local.baseline.aws_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_delivery" {
  count = local.baseline.aws_config ? 1 : 0
  name  = "deliver-to-config-bucket"
  role  = aws_iam_role.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetBucketAcl"]
        Resource = [module.config_bucket[0].bucket_arn, "${module.config_bucket[0].bucket_arn}/*"]
      }],
      local.s.kms_cmk ? [{
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = local.kms_key_arn
      }] : []
    )
  })
}

resource "aws_config_configuration_recorder" "main" {
  count    = local.baseline.aws_config ? 1 : 0
  name     = "${local.prefix}-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  count          = local.baseline.aws_config ? 1 : 0
  name           = "${local.prefix}-delivery"
  s3_bucket_name = module.config_bucket[0].bucket_id
  s3_kms_key_arn = local.kms_key_arn

  depends_on = [aws_config_configuration_recorder.main, module.config_bucket, aws_iam_role_policy.config_delivery]
}

resource "aws_config_configuration_recorder_status" "main" {
  count      = local.baseline.aws_config ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

# --------------------------------------------
# CloudTrail (multi-region, KMS, log file validation, CloudWatch Logs for CIS alarms)
# --------------------------------------------
locals {
  trail_name   = "${local.prefix}-trail"
  trail_arn    = "arn:${data.aws_partition.current.partition}:cloudtrail:${local.region}:${local.account_id}:trail/${local.trail_name}"
  trail_bucket = "${local.prefix}-cloudtrail-${local.account_id}"
}

resource "aws_kms_key" "cloudtrail" {
  count                   = local.baseline.cloudtrail ? 1 : 0
  description             = "${local.prefix} CloudTrail"
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
        Sid       = "CloudTrailEncrypt"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "kms:GenerateDataKey*"
        Resource  = "*"
        Condition = {
          StringEquals = { "aws:SourceArn" = local.trail_arn }
          StringLike   = { "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:${data.aws_partition.current.partition}:cloudtrail:*:${local.account_id}:trail/*" }
        }
      },
      {
        Sid       = "CloudTrailDescribeKey"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "kms:DescribeKey"
        Resource  = "*"
      },
      {
        Sid       = "AccountPrincipalsDecryptLogs"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = ["kms:Decrypt", "kms:ReEncryptFrom"]
        Resource  = "*"
        Condition = {
          StringEquals = { "kms:CallerAccount" = local.account_id }
          StringLike   = { "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:${data.aws_partition.current.partition}:cloudtrail:*:${local.account_id}:trail/*" }
        }
      }
    ]
  })

  tags = local.tags
}

module "cloudtrail_bucket" {
  source = "./modules/s3"
  count  = local.baseline.cloudtrail ? 1 : 0

  bucket_name = local.trail_bucket
  environment = var.environment
  versioning  = true

  lifecycle_rules = [{
    id         = "archive"
    status     = "Enabled"
    transition = { days = 90, storage_class = "GLACIER" }
    expiration = { days = max(local.s.audit_log_retention, 180) }
  }]

  additional_policy_statements = [
    {
      Sid       = "AWSCloudTrailAclCheck"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "s3:GetBucketAcl"
      Resource  = "arn:${data.aws_partition.current.partition}:s3:::${local.trail_bucket}"
      Condition = { StringEquals = { "aws:SourceArn" = local.trail_arn } }
    },
    {
      Sid       = "AWSCloudTrailWrite"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "arn:${data.aws_partition.current.partition}:s3:::${local.trail_bucket}/AWSLogs/${local.account_id}/*"
      Condition = {
        StringEquals = {
          "aws:SourceArn" = local.trail_arn
          "s3:x-amz-acl"  = "bucket-owner-full-control"
        }
      }
    }
  ]

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  count             = local.baseline.cloudtrail ? 1 : 0
  name              = "/aws/cloudtrail/${local.trail_name}"
  retention_in_days = local.s.audit_log_retention
  kms_key_id        = local.kms_key_arn
  tags              = local.tags
}

resource "aws_iam_role" "cloudtrail" {
  count = local.baseline.cloudtrail ? 1 : 0
  name  = "${local.prefix}-cloudtrail-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceArn" = local.trail_arn } }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "cloudtrail" {
  count = local.baseline.cloudtrail ? 1 : 0
  name  = "cloudwatch-logs"
  role  = aws_iam_role.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
    }]
  })
}

resource "aws_cloudtrail" "main" {
  count = local.baseline.cloudtrail ? 1 : 0
  name  = local.trail_name

  s3_bucket_name                = module.cloudtrail_bucket[0].bucket_id
  kms_key_id                    = aws_kms_key.cloudtrail[0].arn
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail[0].arn

  tags = local.tags

  depends_on = [module.cloudtrail_bucket, aws_iam_role_policy.cloudtrail]
}

# --------------------------------------------
# CIS AWS Foundations Benchmark - monitoring controls (metric filters + alarms)
# --------------------------------------------
locals {
  cis_metric_filters = {
    unauthorized-api-calls     = "{ (($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\")) && ($.sourceIPAddress != \"delivery.logs.amazonaws.com\") && ($.eventName != \"HeadBucket\") }"
    console-signin-without-mfa = "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") && ($.userIdentity.type = \"IAMUser\") && ($.responseElements.ConsoleLogin = \"Success\") }"
    root-account-usage         = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
    iam-policy-changes         = "{ ($.eventName = DeleteGroupPolicy) || ($.eventName = DeleteRolePolicy) || ($.eventName = DeleteUserPolicy) || ($.eventName = PutGroupPolicy) || ($.eventName = PutRolePolicy) || ($.eventName = PutUserPolicy) || ($.eventName = CreatePolicy) || ($.eventName = DeletePolicy) || ($.eventName = CreatePolicyVersion) || ($.eventName = DeletePolicyVersion) || ($.eventName = AttachRolePolicy) || ($.eventName = DetachRolePolicy) || ($.eventName = AttachUserPolicy) || ($.eventName = DetachUserPolicy) || ($.eventName = AttachGroupPolicy) || ($.eventName = DetachGroupPolicy) }"
    cloudtrail-config-changes  = "{ ($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging) }"
    console-auth-failures      = "{ ($.eventName = ConsoleLogin) && ($.errorMessage = \"Failed authentication\") }"
    kms-key-disable-or-delete  = "{ ($.eventSource = kms.amazonaws.com) && (($.eventName = DisableKey) || ($.eventName = ScheduleKeyDeletion)) }"
    s3-bucket-policy-changes   = "{ ($.eventSource = s3.amazonaws.com) && (($.eventName = PutBucketAcl) || ($.eventName = PutBucketPolicy) || ($.eventName = PutBucketCors) || ($.eventName = PutBucketLifecycle) || ($.eventName = PutBucketReplication) || ($.eventName = DeleteBucketPolicy) || ($.eventName = DeleteBucketCors) || ($.eventName = DeleteBucketLifecycle) || ($.eventName = DeleteBucketReplication)) }"
    config-changes             = "{ ($.eventSource = config.amazonaws.com) && (($.eventName = StopConfigurationRecorder) || ($.eventName = DeleteDeliveryChannel) || ($.eventName = PutDeliveryChannel) || ($.eventName = PutConfigurationRecorder)) }"
    security-group-changes     = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }"
    nacl-changes               = "{ ($.eventName = CreateNetworkAcl) || ($.eventName = CreateNetworkAclEntry) || ($.eventName = DeleteNetworkAcl) || ($.eventName = DeleteNetworkAclEntry) || ($.eventName = ReplaceNetworkAclEntry) || ($.eventName = ReplaceNetworkAclAssociation) }"
    network-gateway-changes    = "{ ($.eventName = CreateCustomerGateway) || ($.eventName = DeleteCustomerGateway) || ($.eventName = AttachInternetGateway) || ($.eventName = CreateInternetGateway) || ($.eventName = DeleteInternetGateway) || ($.eventName = DetachInternetGateway) }"
    route-table-changes        = "{ ($.eventName = CreateRoute) || ($.eventName = CreateRouteTable) || ($.eventName = ReplaceRoute) || ($.eventName = ReplaceRouteTableAssociation) || ($.eventName = DeleteRouteTable) || ($.eventName = DeleteRoute) || ($.eventName = DisassociateRouteTable) }"
    vpc-changes                = "{ ($.eventName = CreateVpc) || ($.eventName = DeleteVpc) || ($.eventName = ModifyVpcAttribute) || ($.eventName = AcceptVpcPeeringConnection) || ($.eventName = CreateVpcPeeringConnection) || ($.eventName = DeleteVpcPeeringConnection) || ($.eventName = RejectVpcPeeringConnection) }"
    organizations-changes      = "{ ($.eventSource = organizations.amazonaws.com) && (($.eventName = AttachPolicy) || ($.eventName = DetachPolicy) || ($.eventName = UpdatePolicy) || ($.eventName = DeletePolicy) || ($.eventName = LeaveOrganization) || ($.eventName = RemoveAccountFromOrganization) || ($.eventName = MoveAccount)) }"
  }
}

resource "aws_cloudwatch_log_metric_filter" "cis" {
  for_each = local.baseline.cis_alarms ? local.cis_metric_filters : {}

  name           = "${local.prefix}-cis-${each.key}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail[0].name
  pattern        = each.value

  metric_transformation {
    name      = each.key
    namespace = "CISBenchmark/${local.prefix}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "cis" {
  for_each = aws_cloudwatch_log_metric_filter.cis

  alarm_name          = "${local.prefix}-cis-${each.key}"
  alarm_description   = "CIS AWS Foundations Benchmark: ${each.key} detected in CloudTrail"
  namespace           = "CISBenchmark/${local.prefix}"
  metric_name         = each.value.metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --------------------------------------------
# Access Analyzer + EBS encryption by default
# --------------------------------------------
resource "aws_accessanalyzer_analyzer" "main" {
  count         = local.baseline.access_analyzer ? 1 : 0
  analyzer_name = "${local.prefix}-access-analyzer"
  type          = "ACCOUNT"
  tags          = local.tags
}

resource "aws_ebs_encryption_by_default" "main" {
  count   = local.baseline.ebs_encryption ? 1 : 0
  enabled = true
}

resource "aws_ebs_default_kms_key" "main" {
  count   = local.baseline.ebs_encryption && local.s.kms_cmk ? 1 : 0
  key_arn = local.kms_key_arn
}
