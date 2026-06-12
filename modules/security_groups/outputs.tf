output "ecs_tasks_security_group_id" {
  description = "The ID of the ECS tasks security group"
  value       = aws_security_group.container.id
}

output "alb_security_group_id" {
  description = "The ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ecs_instances_security_group_id" {
  description = "The ID of the ECS instances security group"
  value       = aws_security_group.ecs_instances.id
} 