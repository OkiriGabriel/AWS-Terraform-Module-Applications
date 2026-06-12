locals {
  # Map environments to workspace names
  env = {
    "infrastructure-prod" = local.prod
    "infrastructure"      = local.dev
    "prod"                = local.prod
    "dev"                 = local.dev
  }

  # Get current environment settings
  # infrastructure = dev, infrastructure-prod = prod
  current_env = try(local.env[terraform.workspace], local.dev)

  # Basic Settings
  environment  = local.current_env.environment
  project_name = local.current_env.project_name

  # VPC Configuration
  vpc = {
    cidr                 = local.current_env.vpc.cidr
    public_subnets       = local.current_env.vpc.public_subnets
    private_subnets      = local.current_env.vpc.private_subnets
    azs                  = local.current_env.vpc.azs
    single_nat_gateway   = local.current_env.vpc.single_nat_gateway
    enable_nat_gateway   = local.current_env.vpc.enable_nat_gateway
    enable_dns_hostnames = local.current_env.vpc.enable_dns_hostnames
  }

  # RDS Configuration
  rds = {
    instance_class          = local.current_env.rds.instance_class
    allocated_storage       = local.current_env.rds.allocated_storage
    max_allocated_storage   = local.current_env.rds.max_allocated_storage
    multi_az                = local.current_env.rds.multi_az
    deletion_protection     = local.current_env.rds.deletion_protection
    backup_retention_period = local.current_env.rds.backup_retention_period
    backup_window           = local.current_env.rds.backup_window
    maintenance_window      = local.current_env.rds.maintenance_window
    skip_final_snapshot     = local.current_env.rds.skip_final_snapshot
    db_parameters           = local.current_env.rds.db_parameters
  }

  # EC2 Configuration (dev = direct instances, prod = autoscaling)
  ec2 = {
    # Dev environment uses direct EC2 instances (no autoscaling attributes needed)
    frontend = try(local.current_env.ec2.frontend, null)
    backend  = try(local.current_env.ec2.backend, null)
    # Production autoscaling attributes (if they exist)
    instance_type    = try(local.current_env.ec2.instance_type, "t3.medium")
    desired_capacity = try(local.current_env.ec2.desired_capacity, 1)
    max_size         = try(local.current_env.ec2.max_size, 1)
    min_size         = try(local.current_env.ec2.min_size, 1)
  }

  # ECS Configuration
  # ECS Configuration (Production only - dev uses EC2)
  ecs = try(local.current_env.ecs, {
    cluster_name = "N/A-dev-uses-ec2"
    frontend = {
      task_cpu              = 0
      min_capacity          = 0
      max_capacity          = 0
      task_memory           = 0
      container_name        = "N/A-dev-uses-ec2"
      container_port        = 0
      container_image       = "N/A-dev-uses-ec2"
      container_environment = []
      container_secrets     = []
      desired_count         = 0
      log_retention_days    = 0
    }
    backend = {
      task_cpu              = 0
      min_capacity          = 0
      max_capacity          = 0
      task_memory           = 0
      container_name        = "N/A-dev-uses-ec2"
      container_port        = 0
      container_image       = "N/A-dev-uses-ec2"
      container_environment = []
      container_secrets     = []
      desired_count         = 0
      log_retention_days    = 0
    }
    admin = {
      task_cpu              = 0
      min_capacity          = 0
      max_capacity          = 0
      task_memory           = 0
      container_name        = "N/A-dev-uses-ec2"
      container_port        = 0
      container_image       = "N/A-dev-uses-ec2"
      container_environment = []
      container_secrets     = []
      desired_count         = 0
      log_retention_days    = 0
    }
  })

  # ALB Configuration
  # ALB Configuration (Production only - dev uses direct EC2 access)
  alb = try(local.current_env.alb, {
    internal          = false
    target_port       = 80
    listener_port     = 80
    health_check_path = "/"
    max_capacity      = 0
    min_capacity      = 0
    ecs_cluster_name  = "N/A-dev-uses-ec2"
    ecs_service_name  = "N/A-dev-uses-ec2"
  })

  # Security Configuration
  security = {

    container_port = local.current_env.security.container_port
  }

  # DynamoDB configuration (if needed)

  # Domain Configuration

  # Task Resources

  # S3 Configuration
  s3 = local.current_env.s3

  # ElastiCache Configuration
  elasticache = local.current_env.elasticache

  # Monitoring Configuration
  monitoring = local.current_env.monitoring

  # Common Tags
  tags = local.current_env.tags
} 