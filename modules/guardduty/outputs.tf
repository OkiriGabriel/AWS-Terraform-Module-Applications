output "detector_id" {
  description = "The ID of the GuardDuty detector"
  value       = aws_guardduty_detector.main.id
}

output "detector_arn" {
  description = "The ARN of the GuardDuty detector"
  value       = aws_guardduty_detector.main.arn
}

output "sns_topic_arn" {
  description = "The ARN of the SNS topic for GuardDuty findings"
  value       = try(aws_sns_topic.guardduty_findings[0].arn, "")
}

output "findings_bucket_name" {
  description = "The name of the S3 bucket for GuardDuty findings"
  value       = try(aws_s3_bucket.guardduty_findings[0].id, "")
}

output "findings_bucket_arn" {
  description = "The ARN of the S3 bucket for GuardDuty findings"
  value       = try(aws_s3_bucket.guardduty_findings[0].arn, "")
}

output "kms_key_id" {
  description = "The ID of the KMS key used for encryption"
  value       = var.kms_key_id != null ? var.kms_key_id : try(aws_kms_key.guardduty[0].id, "")
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = var.kms_key_id != null ? var.kms_key_id : try(aws_kms_key.guardduty[0].arn, "")
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group for GuardDuty findings"
  value       = try(aws_cloudwatch_log_group.guardduty_findings[0].name, "")
}

output "cloudwatch_event_rule_arn" {
  description = "The ARN of the CloudWatch Event Rule"
  value       = try(aws_cloudwatch_event_rule.guardduty_findings[0].arn, "")
}
