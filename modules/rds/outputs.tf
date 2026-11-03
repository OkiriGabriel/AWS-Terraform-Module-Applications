output "endpoint" {
  description = "host:port"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "Hostname"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "Port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "arn" {
  description = "DB instance ARN"
  value       = aws_db_instance.main.arn
}

output "identifier" {
  description = "DB instance identifier"
  value       = aws_db_instance.main.identifier
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN of the RDS-managed master credentials (JSON: username, password)"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "DB security group"
  value       = aws_security_group.rds.id
}
