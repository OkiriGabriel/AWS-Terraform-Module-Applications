output "primary_endpoint" {
  description = "Primary endpoint (TLS on 6379)"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "reader_endpoint" {
  description = "Reader endpoint"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "port" {
  description = "Port"
  value       = 6379
}

output "auth_secret_arn" {
  description = "Secrets Manager ARN holding the AUTH token"
  value       = aws_secretsmanager_secret.auth.arn
}

output "security_group_id" {
  description = "Redis security group"
  value       = aws_security_group.redis.id
}

output "replication_group_id" {
  description = "Replication group ID"
  value       = aws_elasticache_replication_group.redis.id
}
