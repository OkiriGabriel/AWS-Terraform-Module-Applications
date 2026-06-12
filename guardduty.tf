# GuardDuty Root Module
# Uncomment to enable GuardDuty threat detection


module "guardduty" {
  source = "./guardduty"

  name_prefix = "${local.project_name}-guardduty"
  
  enable                       = true
  enable_s3_protection         = true
  enable_kubernetes_protection = true
  enable_malware_protection    = true
  
  enable_notifications   = true
  notification_emails    = ["security@example.com"]  # Update with your email
  minimum_severity_level = 4.0  # Medium and above
  
  enable_findings_export = true
  enable_cloudwatch_logs = true
  log_retention_days     = 90
  
  auto_archive_low_severity = false
  
  tags = local.tags
}

# Outputs
output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = try(module.guardduty.detector_id, null)
}

output "guardduty_sns_topic_arn" {
  description = "GuardDuty SNS topic ARN"
  value       = try(module.guardduty.sns_topic_arn, null)
}

output "guardduty_findings_bucket" {
  description = "S3 bucket for GuardDuty findings"
  value       = try(module.guardduty.findings_bucket_name, null)
}
