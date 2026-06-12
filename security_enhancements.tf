# Enhanced Security Configuration
# WAF, GuardDuty, Security Hub, and additional security measures

# WAF v2 for ALB Protection
resource "aws_wafv2_web_acl" "example" {
  count = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name  = "${local.environment}-boiler-plate-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1

    override_action {
      none {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }

    action {
      block {}
    }
  }

  # AWS Managed Rules - Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # SQL Injection Protection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Geographic blocking (example for high-risk countries)
  rule {
    name     = "GeoBlockingRule"
    priority = 4

    statement {
      geo_match_statement {
        country_codes = ["CN", "RU", "KP"] # Configurable based on requirements
      }
    }

    action {
      block {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoBlockingMetric"
      sampled_requests_enabled   = true
    }
  }

  # API Rate limiting for /api/* endpoints
  rule {
    name     = "APIRateLimitRule"
    priority = 5

    statement {
      rate_based_statement {
        limit              = 500
        aggregate_key_type = "IP"

        scope_down_statement {
          byte_match_statement {
            search_string = "/api/"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "STARTS_WITH"
          }
        }
      }
    }

    action {
      block {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "APIRateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ApplicationWAF"
    sampled_requests_enabled   = true
  }

  tags = merge(local.tags, {
    Purpose = "Web Application Firewall"
  })
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "example_alb" {
  count        = terraform.workspace == "infrastructure-prod" ? 1 : 0
  resource_arn = aws_lb.main[0].arn
  web_acl_arn  = aws_wafv2_web_acl.example[0].arn
}

# GuardDuty for threat detection (Production only - requires subscription)
resource "aws_guardduty_detector" "example" {
  count  = terraform.workspace == "infrastructure-prod" ? 1 : 0
  enable = true

  tags = merge(local.tags, {
    Purpose     = "Threat Detection"
    Environment = local.environment
  })
}

# GuardDuty S3 Protection (Production only - cost optimization)
resource "aws_guardduty_detector_feature" "s3_data_events" {
  count       = terraform.workspace == "infrastructure-prod" ? 1 : 0
  detector_id = aws_guardduty_detector.example[0].id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

# GuardDuty Malware Protection (Production only - cost optimization)
resource "aws_guardduty_detector_feature" "ebs_malware_protection" {
  count       = terraform.workspace == "infrastructure-prod" ? 1 : 0
  detector_id = aws_guardduty_detector.example[0].id
  name        = "EBS_MALWARE_PROTECTION"
  status      = "ENABLED"

  # additional_configuration {
  #   name   = "EBS_MALWARE_SCAN_EC2_INSTANCE_WITH_FINDINGS"
  #   status = "ENABLED"
  # }
}

# GuardDuty RDS Protection (Production only - cost optimization)
resource "aws_guardduty_detector_feature" "rds_login_events" {
  count       = terraform.workspace == "infrastructure-prod" ? 1 : 0
  detector_id = aws_guardduty_detector.example[0].id
  name        = "RDS_LOGIN_EVENTS"
  status      = "ENABLED"
}

# Security Hub for centralized security findings (Production only - requires subscription)
resource "aws_securityhub_account" "example" {
  count = terraform.workspace == "infrastructure-prod" ? 1 : 0
}

# Config for configuration compliance
resource "aws_config_configuration_recorder_status" "example" {
  name       = aws_config_configuration_recorder.example.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.example]
}

resource "aws_config_configuration_recorder" "example" {
  name     = "${local.environment}-boiler-plate-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "example" {
  name           = "${local.environment}-boiler-plate-delivery-channel"
  s3_bucket_name = module.s3_configs.bucket_id
  # Config appends AWSLogs/... itself; the prefix must NOT contain "AWSLogs/" (InvalidS3KeyPrefixException).
  s3_key_prefix = "aws-config/${local.environment}"

  depends_on = [
    aws_iam_role_policy_attachment.config,
    aws_iam_role_policy.config_s3_delivery,
    aws_s3_bucket_policy.config_delivery,
  ]
}

# IAM Role for AWS Config
resource "aws_iam_role" "config" {
  name = "${local.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Explicit S3 delivery permissions for the configs bucket (managed policy alone is often insufficient).
resource "aws_iam_role_policy" "config_s3_delivery" {
  name = "${local.environment}-config-s3-delivery"
  role = aws_iam_role.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ConfigWriteConfigBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          module.s3_configs.bucket_arn,
          "${module.s3_configs.bucket_arn}/*"
        ]
      }
    ]
  })
}

# Allow the Config service to verify ACL and write snapshots (required for delivery channel).
resource "aws_s3_bucket_policy" "config_delivery" {
  bucket = module.s3_configs.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = module.s3_configs.bucket_arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${module.s3_configs.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# VPC Flow Logs for network monitoring
resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = module.vpc.vpc_id
}

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name              = "/boiler-plate/${local.environment}/vpc-flow-logs"
  retention_in_days = 7

  tags = local.tags
}

resource "aws_iam_role" "flow_log" {
  name = "${local.environment}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "flow_log" {
  name = "${local.environment}-flow-log-policy"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}