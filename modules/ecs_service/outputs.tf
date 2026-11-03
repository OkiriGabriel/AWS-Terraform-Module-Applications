output "service_name" {
  description = "Name of the ECS service"
  value       = local.service.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = local.service.id
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.main.arn
}

output "task_execution_role_arn" {
  description = "ARN of the task execution role"
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN of the task role"
  value       = aws_iam_role.task.arn
}
output "task_role_name" {
  description = "Name of the task role (attach extra application policies here)"
  value       = aws_iam_role.task.name
}
