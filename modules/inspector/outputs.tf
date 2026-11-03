output "enabler_id" {
  description = "The ID of the Inspector enabler"
  value       = aws_inspector2_enabler.main.id
}

output "sns_topic_arn" {
  description = "The ARN of the SNS topic for Inspector findings"
  value       = try(aws_sns_topic.inspector_findings[0].arn, "")
}

output "reports_bucket_name" {
  description = "The name of the S3 bucket for Inspector reports"
  value       = try(aws_s3_bucket.inspector_reports[0].id, "")
}

output "reports_bucket_arn" {
  description = "The ARN of the S3 bucket for Inspector reports"
  value       = try(aws_s3_bucket.inspector_reports[0].arn, "")
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group for Inspector findings"
  value       = try(aws_cloudwatch_log_group.inspector_findings[0].name, "")
}

output "cloudwatch_event_rule_arn" {
  description = "The ARN of the CloudWatch Event Rule"
  value       = try(aws_cloudwatch_event_rule.inspector_findings[0].arn, "")
}

output "remediation_role_arn" {
  description = "The ARN of the IAM role for automated remediation"
  value       = try(aws_iam_role.inspector_remediation[0].arn, "")
}

output "high_severity_alarm_arn" {
  description = "The ARN of the high severity findings alarm"
  value       = try(aws_cloudwatch_metric_alarm.high_severity_findings[0].arn, "")
}

output "account_id" {
  description = "The AWS account ID where Inspector is enabled"
  value       = data.aws_caller_identity.current.account_id
}

output "enabled_resource_types" {
  description = "List of resource types enabled for Inspector scanning"
  value       = var.resource_types
}
