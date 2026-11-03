locals {
  engine_version = coalesce(var.engine_version, var.engine == "postgres" ? "16" : "8.0")
  port           = var.engine == "postgres" ? 5432 : 3306
  family         = var.engine == "postgres" ? "postgres${split(".", local.engine_version)[0]}" : "mysql${join(".", slice(split(".", local.engine_version), 0, 2))}"

  # Encryption in transit is enforced by the database itself, not left to clients.
  tls_parameters = var.engine == "postgres" ? { "rds.force_ssl" = "1" } : { "require_secure_transport" = "ON" }
  parameters     = merge(local.tls_parameters, var.parameters)
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds"
  description = "RDS ${var.engine}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-rds" })
}

resource "aws_vpc_security_group_ingress_rule" "rds" {
  for_each = var.allowed_security_groups

  security_group_id            = aws_security_group.rds.id
  description                  = "Database clients"
  ip_protocol                  = "tcp"
  from_port                    = local.port
  to_port                      = local.port
  referenced_security_group_id = each.value
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.name}-db"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_db_parameter_group" "main" {
  name_prefix = "${var.name}-${replace(local.family, ".", "-")}-"
  family      = local.family

  dynamic "parameter" {
    for_each = local.parameters
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_db_instance" "main" {
  identifier     = "${var.name}-db"
  engine         = var.engine
  engine_version = local.engine_version
  port           = local.port
  instance_class = var.instance_class
  db_name        = var.db_name
  username       = var.username

  # Password generated + rotated by RDS in Secrets Manager; never in Terraform state.
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  iam_database_authentication_enabled   = true
  publicly_accessible                   = false
  auto_minor_version_upgrade            = true
  copy_tags_to_snapshot                 = true
  enabled_cloudwatch_logs_exports       = var.engine == "mysql" ? ["error", "slowquery"] : ["postgresql"]
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.kms_key_arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null

  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  multi_az                  = var.multi_az
  backup_retention_period   = var.backup_retention_period
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:30-sun:05:30"
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-db-final"

  tags = merge(var.tags, var.backup_tags, { Name = "${var.name}-db" })
}
