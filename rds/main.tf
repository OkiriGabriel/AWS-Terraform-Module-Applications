# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-rds-sg"
    }
  )
}

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-db-subnet-group"
    }
  )
}

# RDS Parameter Group
resource "aws_db_parameter_group" "main" {
  name   = "${var.environment}-db-parameter-group"
  family = var.engine == "mysql" ? "mysql8.0" : "postgres17"

  dynamic "parameter" {
    for_each = var.engine == "mysql" ? {
      max_connections         = "100"
      innodb_buffer_pool_size = "{DBInstanceClassMemory*3/4}"
      } : {
      shared_buffers       = "256000"
      max_connections      = "100"
      work_mem             = "4096"
      maintenance_work_mem = "65536"
    }
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }

  tags = var.tags
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier              = "${var.environment}-db"
  engine                  = var.engine
  engine_version          = var.engine_version
  port                    = var.port
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  max_allocated_storage   = var.max_allocated_storage
  storage_type            = "gp2"
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  parameter_group_name    = aws_db_parameter_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  db_subnet_group_name    = aws_db_subnet_group.main.name
  skip_final_snapshot     = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  multi_az                = var.environment == "prod" ? true : false
  deletion_protection     = var.environment == "prod" ? true : false

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-db"
    }
  )
} 