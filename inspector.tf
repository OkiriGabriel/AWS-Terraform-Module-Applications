# AWS Inspector Root Module
# Uncomment to enable Inspector vulnerability scanning


module "inspector" {
  source = "./inspector"

  name_prefix = "${local.project_name}-inspector"
  
  resource_types = ["EC2", "ECR", "LAMBDA"]
  
  enable_notifications = true
  notification_emails  = ["security@example.com"]  # Update with your email
  severity_filter      = ["CRITICAL", "HIGH"]
  
  enable_cloudwatch_logs = true
  log_retention_days     = 90
  
  enable_report_export  = true
  report_retention_days = 365
  
  enable_alarms           = true
  high_severity_threshold = 1
  
  tags = local.tags
}

# Outputs
output "inspector_enabler_id" {
  description = "Inspector enabler ID"
  value       = try(module.inspector.enabler_id, null)
}

output "inspector_sns_topic_arn" {
  description = "Inspector SNS topic ARN"
  value       = try(module.inspector.sns_topic_arn, null)
}

output "inspector_reports_bucket" {
  description = "S3 bucket for Inspector reports"
  value       = try(module.inspector.reports_bucket_name, null)
}

output "inspector_enabled_resource_types" {
  description = "Resource types enabled for scanning"
  value       = try(module.inspector.enabled_resource_types, null)
}

