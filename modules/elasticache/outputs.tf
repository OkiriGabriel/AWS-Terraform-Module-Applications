output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_cluster.redis.port
}

output "redis_cluster_id" {
  description = "Redis cluster ID"
  value       = aws_elasticache_cluster.redis.cluster_id
}

output "security_group_id" {
  description = "Redis security group ID"
  value       = aws_security_group.redis.id
}