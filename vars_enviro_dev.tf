# ============================================
# DEVELOPMENT ENVIRONMENT CONFIGURATION
# ============================================
# This file contains all configuration for the development environment.
# Update the values below to match your project requirements.
#
# IMPORTANT: S3 bucket names must be globally unique across all AWS accounts.
# Update all bucket names and key pair names before deploying.

locals {
  # Development Environment
  dev = {
    environment  = "dev"
    project_name = "my-project"  # Change this to your project name
    vpc = {
      cidr                       = "10.0.0.0/16"
      public_subnets             = ["10.0.1.0/24", "10.0.2.0/24"]
      private_subnets            = ["10.0.10.0/24", "10.0.20.0/24"]
      azs                        = ["us-east-1a", "us-east-1b"]
      single_nat_gateway         = true
      enable_nat_gateway         = true
      enable_dns_hostnames       = true
      enable_dns_support         = true
      enable_flow_log            = true
      flow_log_retention_in_days = 7
    }
    rds = {
      instance_class          = "db.t3.micro"
      allocated_storage       = 20
      max_allocated_storage   = 100
      multi_az                = false
      deletion_protection     = false
      db_name                 = "app_dev_db"
      backup_retention_period = 7
      backup_window           = "03:00-04:00"
      maintenance_window      = "Mon:04:00-Mon:05:00"
      engine                  = "mysql"
      engine_version          = "8.0"
      port                    = 3306
      skip_final_snapshot     = true
      db_parameters           = []
    }
    ec2 = {
      # t3.micro: Free Tier–eligible. t3.medium fails on accounts restricted to Free Tier types only.
      # To use t3.medium (2 vCPU each), use a full paid account / leave Free Tier–only limits, then bump types here.
      frontend = {
        instance_type = "t3.medium"
        ami_id        = "ami-0ec10929233384c7f" # Amazon Linux 2 us-east-1
        key_name      = "my-dev-key"  # Change to your key pair name
      }
      backend = {
        instance_type = "t3.medium"
        ami_id        = "ami-0ec10929233384c7f" # Amazon Linux 2 us-east-1
        key_name      = "my-dev-key"  # Change to your key pair name
      }
    }
    # Dev environment uses EC2 instances, not ECS
    # ECS configuration removed for development
    # Dev environment uses direct EC2 access, no ALB needed
    # ALB configuration removed for development
    security = {
      container_port = 80
      frontend_port  = 80
      ingress_rules = [
        {
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        },
        {
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        },
        {
          from_port   = 22
          to_port     = 22
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
    }
    domain_config = {
      domain_name = "dev.example.com"  # Change to your domain
    }
    monitoring_config = {
      enable_cloudwatch = true
      enable_xray       = false
    }
    tags = {
      Environment = "dev"
      Project     = "my-project"  # Change to your project name
      ManagedBy   = "terraform"
      Owner       = "DevTeam"
      Company     = "my-company"  # Change to your company name
    }
    s3 = {
      buckets = {
        media = {
          name            = "my-project-media-dev"  # Must be globally unique
          versioning      = false
          lifecycle_rules = []
        }
        static = {
          name            = "my-project-static-dev"  # Must be globally unique
          versioning      = false
          lifecycle_rules = []
        }
        backups = {
          name       = "my-project-backups-dev"  # Must be globally unique
          versioning = true
          lifecycle_rules = [
            {
              id     = "glacier_transition"
              status = "Enabled"
              transition = {
                days          = 90
                storage_class = "GLACIER"
              }
            }
          ]
        }
        configs = {
          name            = "my-project-configs-dev"  # Must be globally unique
          versioning      = true
          lifecycle_rules = []
        }
      }
    }
    # Dev-specific placeholder configs (not actually used)
    elasticache = {
      node_type                = "cache.t3.micro"
      num_cache_nodes          = 1
      parameter_group_name     = "default.redis7"
      port                     = 6379
      engine_version           = "7.0"
      apply_immediately        = true
      maintenance_window       = "sun:05:00-sun:06:00"
      snapshot_retention_limit = 0
      snapshot_window          = "04:00-05:00"
    }
    monitoring = {
      instance_type = "t3.micro"
      ami_id        = "ami-0ec10929233384c7f" # Amazon Linux 2 us-east-1
      key_name      = "my-dev-key"  # Change to your key pair name
      services = {
        prometheus = { port = 9090, path = "/prometheus" }
        grafana    = { port = 3000, path = "/grafana" }
        blackbox   = { port = 9115, path = "/blackbox" }
        sonarqube  = { port = 9000, path = "/sonar" }
      }
    }
  }
}