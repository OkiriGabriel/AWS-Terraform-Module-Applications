output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "tasks_security_group_id" {
  description = "Service tasks security group ID (allow this SG in data-store security groups)"
  value       = aws_security_group.tasks.id
}
