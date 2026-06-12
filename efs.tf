# Amazon EFS for WordPress Shared Storage
# Enables WordPress scaling across multiple ECS tasks

# EFS File System (Production only)
resource "aws_efs_file_system" "wordpress" {
  count          = terraform.workspace == "infrastructure-prod" ? 1 : 0
  creation_token = "${local.environment}-wordpress-efs"

  performance_mode                = "generalPurpose"
  throughput_mode                 = "provisioned"
  provisioned_throughput_in_mibps = 20

  encrypted = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = merge(local.tags, {
    Name    = "${local.environment}-wordpress-efs"
    Purpose = "WordPress shared storage"
  })
}

# EFS Mount Targets (Multi-AZ)
resource "aws_efs_mount_target" "wordpress_a" {
  count           = terraform.workspace == "infrastructure-prod" ? 1 : 0
  file_system_id  = aws_efs_file_system.wordpress[0].id
  subnet_id       = module.vpc.private_subnet_ids[0]
  security_groups = [aws_security_group.efs[0].id]
}

resource "aws_efs_mount_target" "wordpress_b" {
  count           = terraform.workspace == "infrastructure-prod" ? 1 : 0
  file_system_id  = aws_efs_file_system.wordpress[0].id
  subnet_id       = module.vpc.private_subnet_ids[1]
  security_groups = [aws_security_group.efs[0].id]
}

# EFS Security Group
resource "aws_security_group" "efs" {
  count       = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name        = "${local.environment}-efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [module.security_groups.ecs_tasks_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.environment}-efs-sg"
  })
}

# EFS Access Point for WordPress
resource "aws_efs_access_point" "wordpress" {
  count          = terraform.workspace == "infrastructure-prod" ? 1 : 0
  file_system_id = aws_efs_file_system.wordpress[0].id

  posix_user {
    gid = 33
    uid = 33
  }

  tags = merge(local.tags, {
    Name = "${local.environment}-wordpress-access-point"
  })
}