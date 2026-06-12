# AWS Inspector Module
# Provides automated security assessment and vulnerability scanning

# Enable Inspector for the account
resource "aws_inspector2_enabler" "main" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = var.resource_types
}

# SNS Topic for Inspector Findings
resource "aws_sns_topic" "inspector_findings" {
  count = var.enable_notifications ? 1 : 0
  name  = "${var.name_prefix}-inspector-findings"

  tags = var.tags
}

resource "aws_sns_topic_policy" "inspector_findings" {
  count  = var.enable_notifications ? 1 : 0
  arn    = aws_sns_topic.inspector_findings[0].arn
  policy = data.aws_iam_policy_document.sns_topic_policy[0].json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  count = var.enable_notifications ? 1 : 0

  statement {
    sid    = "AllowInspectorToPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = [
      "SNS:Publish"
    ]

    resources = [
      aws_sns_topic.inspector_findings[0].arn
    ]
  }
}

# Subscribe email addresses to SNS topic
resource "aws_sns_topic_subscription" "inspector_email" {
  count     = var.enable_notifications ? length(var.notification_emails) : 0
  topic_arn = aws_sns_topic.inspector_findings[0].arn
  protocol  = "email"
  endpoint  = var.notification_emails[count.index]
}

# CloudWatch Event Rule for Inspector Findings
resource "aws_cloudwatch_event_rule" "inspector_findings" {
  count       = var.enable_notifications ? 1 : 0
  name        = "${var.name_prefix}-inspector-findings"
  description = "Capture Inspector findings"

  event_pattern = jsonencode({
    source      = ["aws.inspector2"]
    detail-type = ["Inspector2 Finding"]
    detail = {
      severity = var.severity_filter != null ? var.severity_filter : null
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "sns" {
  count     = var.enable_notifications ? 1 : 0
  rule      = aws_cloudwatch_event_rule.inspector_findings[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.inspector_findings[0].arn

  input_transformer {
    input_paths = {
      severity           = "$.detail.severity"
      title              = "$.detail.title"
      finding_arn        = "$.detail.findingArn"
      resource_id        = "$.detail.resources[0].id"
      resource_type      = "$.detail.resources[0].type"
      first_observed_at  = "$.detail.firstObservedAt"
      description        = "$.detail.description"
      remediation        = "$.detail.remediation.recommendation.text"
    }

    input_template = <<TEMPLATE
"AWS Inspector Finding"
"Severity: <severity>"
"Title: <title>"
"Resource: <resource_type> - <resource_id>"
"First Observed: <first_observed_at>"
"Description: <description>"
"Remediation: <remediation>"
"Finding ARN: <finding_arn>"
TEMPLATE
  }
}

# CloudWatch Log Group for Inspector Findings
resource "aws_cloudwatch_log_group" "inspector_findings" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/inspector/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# EventBridge to CloudWatch Logs
resource "aws_cloudwatch_event_rule" "inspector_to_logs" {
  count       = var.enable_cloudwatch_logs ? 1 : 0
  name        = "${var.name_prefix}-inspector-to-logs"
  description = "Send Inspector findings to CloudWatch Logs"

  event_pattern = jsonencode({
    source      = ["aws.inspector2"]
    detail-type = ["Inspector2 Finding"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "logs" {
  count     = var.enable_cloudwatch_logs ? 1 : 0
  rule      = aws_cloudwatch_event_rule.inspector_to_logs[0].name
  target_id = "SendToCloudWatchLogs"
  arn       = aws_cloudwatch_log_group.inspector_findings[0].arn
}

resource "aws_cloudwatch_log_resource_policy" "inspector" {
  count           = var.enable_cloudwatch_logs ? 1 : 0
  policy_name     = "${var.name_prefix}-inspector-log-policy"
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
      "${aws_cloudwatch_log_group.inspector_findings[0].arn}:*"
    ]
  }
}

# S3 Bucket for Inspector Reports
resource "aws_s3_bucket" "inspector_reports" {
  count  = var.enable_report_export ? 1 : 0
  bucket = "${var.name_prefix}-inspector-reports-${data.aws_caller_identity.current.account_id}"

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "inspector_reports" {
  count  = var.enable_report_export ? 1 : 0
  bucket = aws_s3_bucket.inspector_reports[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "inspector_reports" {
  count  = var.enable_report_export ? 1 : 0
  bucket = aws_s3_bucket.inspector_reports[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
  }
}

resource "aws_s3_bucket_public_access_block" "inspector_reports" {
  count  = var.enable_report_export ? 1 : 0
  bucket = aws_s3_bucket.inspector_reports[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "inspector_reports" {
  count  = var.enable_report_export ? 1 : 0
  bucket = aws_s3_bucket.inspector_reports[0].id

  rule {
    id     = "delete-old-reports"
    status = var.report_retention_days > 0 ? "Enabled" : "Disabled"

    expiration {
      days = var.report_retention_days
    }
  }
}

# Lambda function for automated remediation (optional)
resource "aws_iam_role" "inspector_remediation" {
  count = var.enable_automated_remediation ? 1 : 0
  name  = "${var.name_prefix}-inspector-remediation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "inspector_remediation_basic" {
  count      = var.enable_automated_remediation ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.inspector_remediation[0].name
}

resource "aws_iam_role_policy" "inspector_remediation_custom" {
  count = var.enable_automated_remediation ? 1 : 0
  name  = "${var.name_prefix}-inspector-remediation-policy"
  role  = aws_iam_role.inspector_remediation[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:CreateTags",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "inspector2:ListFindings",
          "inspector2:BatchGetFindingDetails"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Alarm for High Severity Findings
resource "aws_cloudwatch_metric_alarm" "high_severity_findings" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.name_prefix}-high-severity-findings"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HighSeverityFindings"
  namespace           = "AWS/Inspector"
  period              = 300
  statistic           = "Sum"
  threshold           = var.high_severity_threshold
  alarm_description   = "Alert when high severity Inspector findings exceed threshold"
  alarm_actions       = var.enable_notifications ? [aws_sns_topic.inspector_findings[0].arn] : []

  tags = var.tags
}

# Inspector Suppression Rules (for false positives)
resource "aws_inspector2_member_association" "delegated_admin" {
  count      = var.delegated_admin_account_id != null ? 1 : 0
  account_id = var.delegated_admin_account_id
}

data "aws_caller_identity" "current" {}
