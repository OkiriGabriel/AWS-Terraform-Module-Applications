output "security_group_id" {
  description = "Security group ID for monitoring server"
  value       = aws_security_group.monitoring.id
}

output "instance_profile_name" {
  description = "Instance profile name for monitoring server"
  value       = aws_iam_instance_profile.monitoring.name
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group name for monitoring server"
  value       = aws_autoscaling_group.monitoring.name
}