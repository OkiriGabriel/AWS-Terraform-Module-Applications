# GuardDuty Module
# Provides intelligent threat detection and continuous security monitoring

resource "aws_guardduty_detector" "main" {
  enable                       = var.enable
  finding_publishing_frequency = var.finding_publishing_frequency

  datasources {
    s3_logs {
      enable = var.enable_s3_protection
    }
    kubernetes {
      audit_logs {
        enable = var.enable_kubernetes_protection
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = var.enable_malware_protection
        }
      }
    }
  }

  tags = var.tags
}

# SNS Topic for GuardDuty Findings
resource "aws_sns_topic" "guardduty_findings" {
  count = var.enable_notifications ? 1 : 0
  name  = "${var.name_prefix}-guardduty-findings"

  tags = var.tags
}

resource "aws_sns_topic_policy" "guardduty_findings" {
  count  = var.enable_notifications ? 1 : 0
  arn    = aws_sns_topic.guardduty_findings[0].arn
  policy = data.aws_iam_policy_document.sns_topic_policy[0].json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  count = var.enable_notifications ? 1 : 0

  statement {
    sid    = "AllowGuardDutyToPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = [
      "SNS:Publish"
    ]

    resources = [
      aws_sns_topic.guardduty_findings[0].arn
    ]
  }
}

# Subscribe email addresses to SNS topic
resource "aws_sns_topic_subscription" "guardduty_email" {
  count     = var.enable_notifications ? length(var.notification_emails) : 0
  topic_arn = aws_sns_topic.guardduty_findings[0].arn
  protocol  = "email"
  endpoint  = var.notification_emails[count.index]
}

# CloudWatch Event Rule for GuardDuty Findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count       = var.enable_notifications ? 1 : 0
  name        = "${var.name_prefix}-guardduty-findings"
  description = "Capture all GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = var.minimum_severity_level != null ? {
        "numeric" = [
          ">=",
          var.minimum_severity_level
        ]
      } : null
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "sns" {
  count     = var.enable_notifications ? 1 : 0
  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.guardduty_findings[0].arn

  input_transformer {
    input_paths = {
      severity    = "$.detail.severity"
      Finding_ID  = "$.detail.id"
      Finding_Type = "$.detail.type"
      region      = "$.region"
      account     = "$.detail.accountId"
      time        = "$.time"
      description = "$.detail.description"
    }

    input_template = <<TEMPLATE
"AWS GuardDuty Finding in <region> for Account: <account>"
"Finding ID: <Finding_ID>"
"Finding Type: <Finding_Type>"
"Severity: <severity>"
"Time: <time>"
"Description: <description>"
TEMPLATE
  }
}

# S3 Bucket for GuardDuty Findings Export
resource "aws_s3_bucket" "guardduty_findings" {
  count  = var.enable_findings_export ? 1 : 0
  bucket = "${var.name_prefix}-guardduty-findings-${data.aws_caller_identity.current.account_id}"

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "guardduty_findings" {
  count  = var.enable_findings_export ? 1 : 0
  bucket = aws_s3_bucket.guardduty_findings[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "guardduty_findings" {
  count  = var.enable_findings_export ? 1 : 0
  bucket = aws_s3_bucket.guardduty_findings[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
  }
}

resource "aws_s3_bucket_public_access_block" "guardduty_findings" {
  count  = var.enable_findings_export ? 1 : 0
  bucket = aws_s3_bucket.guardduty_findings[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "guardduty_findings" {
  count  = var.enable_findings_export ? 1 : 0
  bucket = aws_s3_bucket.guardduty_findings[0].id
  policy = data.aws_iam_policy_document.guardduty_bucket_policy[0].json
}

data "aws_iam_policy_document" "guardduty_bucket_policy" {
  count = var.enable_findings_export ? 1 : 0

  statement {
    sid    = "AllowGuardDutyGetBucketLocation"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketLocation"
    ]

    resources = [
      aws_s3_bucket.guardduty_findings[0].arn
    ]
  }

  statement {
    sid    = "AllowGuardDutyPutObject"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.guardduty_findings[0].arn}/*"
    ]
  }

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*"
    ]

    resources = [
      aws_s3_bucket.guardduty_findings[0].arn,
      "${aws_s3_bucket.guardduty_findings[0].arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# KMS Key for GuardDuty Findings Encryption
resource "aws_kms_key" "guardduty" {
  count                   = var.enable_findings_export && var.kms_key_id == null ? 1 : 0
  description             = "KMS key for GuardDuty findings encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = var.tags
}

resource "aws_kms_alias" "guardduty" {
  count         = var.enable_findings_export && var.kms_key_id == null ? 1 : 0
  name          = "alias/${var.name_prefix}-guardduty"
  target_key_id = aws_kms_key.guardduty[0].key_id
}

# GuardDuty Filter for Auto-Archive Low Severity Findings
resource "aws_guardduty_filter" "auto_archive_low_severity" {
  count       = var.auto_archive_low_severity ? 1 : 0
  name        = "auto-archive-low-severity"
  action      = "ARCHIVE"
  detector_id = aws_guardduty_detector.main.id
  rank        = 1

  finding_criteria {
    criterion {
      field      = "severity"
      less_than  = "4"
    }
  }

  description = "Automatically archive low severity findings (severity < 4)"
}

# GuardDuty ThreatIntelSet (Optional - for custom threat intelligence)
resource "aws_guardduty_threatintelset" "custom" {
  count       = var.threat_intel_set_location != null ? 1 : 0
  name        = "${var.name_prefix}-custom-threat-intel"
  detector_id = aws_guardduty_detector.main.id
  format      = var.threat_intel_set_format
  location    = var.threat_intel_set_location
  activate    = true

  tags = var.tags
}

# GuardDuty IPSet for Trusted IPs (Optional)
resource "aws_guardduty_ipset" "trusted" {
  count       = var.trusted_ip_list_location != null ? 1 : 0
  name        = "${var.name_prefix}-trusted-ips"
  detector_id = aws_guardduty_detector.main.id
  format      = "TXT"
  location    = var.trusted_ip_list_location
  activate    = true

  tags = var.tags
}

# CloudWatch Log Group for GuardDuty Findings
resource "aws_cloudwatch_log_group" "guardduty_findings" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/guardduty/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# EventBridge to CloudWatch Logs
resource "aws_cloudwatch_event_rule" "guardduty_to_logs" {
  count       = var.enable_cloudwatch_logs ? 1 : 0
  name        = "${var.name_prefix}-guardduty-to-logs"
  description = "Send GuardDuty findings to CloudWatch Logs"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "logs" {
  count     = var.enable_cloudwatch_logs ? 1 : 0
  rule      = aws_cloudwatch_event_rule.guardduty_to_logs[0].name
  target_id = "SendToCloudWatchLogs"
  arn       = aws_cloudwatch_log_group.guardduty_findings[0].arn
}

resource "aws_cloudwatch_log_resource_policy" "guardduty" {
  count           = var.enable_cloudwatch_logs ? 1 : 0
  policy_name     = "${var.name_prefix}-guardduty-log-policy"
  policy_document = data.aws_iam_policy_document.cloudwatch_log_policy[0].json
}

data "aws_iam_policy_document" "cloudwatch_log_policy" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "${aws_cloudwatch_log_group.guardduty_findings[0].arn}:*"
    ]
  }
}

data "aws_caller_identity" "current" {}
