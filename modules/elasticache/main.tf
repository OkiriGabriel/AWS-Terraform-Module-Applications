resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.name}-redis"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "redis" {
  name        = "${var.name}-redis"
  description = "ElastiCache Redis"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-redis" })
}

resource "aws_vpc_security_group_ingress_rule" "redis" {
  for_each = var.allowed_security_groups

  security_group_id            = aws_security_group.redis.id
  description                  = "Redis clients"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = each.value
}

# AUTH token: generated here, stored only in Secrets Manager for apps to read.
resource "random_password" "auth" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "auth" {
  name_prefix             = "${var.name}-redis-auth-"
  description             = "AUTH token for ${var.name} Redis"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "auth" {
  secret_id     = aws_secretsmanager_secret.auth.id
  secret_string = random_password.auth.result
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.name}-redis"
  description          = "${var.name} Redis"
  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_clusters   = var.num_nodes
  port                 = 6379
  parameter_group_name = var.parameter_group_name

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  automatic_failover_enabled = var.num_nodes > 1
  multi_az_enabled           = var.num_nodes > 1

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  transit_encryption_enabled = true
  auth_token                 = random_password.auth.result

  snapshot_retention_limit   = var.snapshot_retention_days
  snapshot_window            = "02:00-03:00"
  maintenance_window         = "sun:05:00-sun:06:00"
  auto_minor_version_upgrade = true
  apply_immediately          = false

  tags = var.tags
}
