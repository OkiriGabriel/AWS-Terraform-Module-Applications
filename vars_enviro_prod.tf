locals {
  # Production Environment
  prod = {
    environment  = "prod"
    project_name = "boiler-plate"
    vpc = {
      cidr                       = "10.0.0.0/16"
      public_subnets             = ["10.0.1.0/24", "10.0.2.0/24"]   # boiler-plate-public-a, boiler-plate-public-b
      private_subnets            = ["10.0.10.0/24", "10.0.20.0/24"] # boiler-plate-app-private-a, boiler-plate-app-private-b
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
      deletion_protection     = true
      db_name                 = "app_prod_db"
      backup_retention_period = 7
      backup_window           = "03:00-04:00"
      maintenance_window      = "Mon:04:00-Mon:05:00"
      engine                  = "mysql"
      engine_version          = "8.0"
      port                    = 3306
      db_parameters = [
        {
          name  = "max_connections"
          value = "100"
        },
        {
          name  = "shared_buffers"
          value = "256MB"
        },
        {
          name  = "work_mem"
          value = "4MB"
        }
      ]
      skip_final_snapshot = false
    }
    ec2 = {
      instance_type    = "t3.micro"
      ami_id           = "ami-0d05471b100e9083f" # Amazon Linux 2 us-east-1
      desired_capacity = 1
      min_size         = 1
      max_size         = 2
      key_name         = "boiler-plate-prod-key"
    }
    ecs = {
      cluster_name = "boiler-plate-prod-cluster"
      frontend = {
        task_cpu                  = 1024
        task_memory               = 2048
        min_capacity              = 1
        max_capacity              = 4
        container_port            = 80
        container_image           = "nginx:latest"
        desired_count             = 1
        container_name            = "boiler-plate-frontend"
        service_name              = "prod-frontend-service"
        enable_container_insights = true
        log_retention_days        = 30
        container_environment     = []
        container_secrets         = []
      }
      backend = {
        task_cpu                  = 1024
        task_memory               = 2048
        container_port            = 3000
        container_image           = "node:18-alpine"
        desired_count             = 1
        min_capacity              = 1
        max_capacity              = 6
        container_name            = "boiler-plate-backend"
        service_name              = "prod-backend-service"
        enable_container_insights = true
        log_retention_days        = 30
        container_environment     = []
        container_secrets         = []
      }
      admin = {
        task_cpu                  = 512
        task_memory               = 1024
        min_capacity              = 1
        max_capacity              = 2
        container_port            = 80
        container_image           = "nginx:latest"
        desired_count             = 1
        container_name            = "boiler-plate-admin"
        service_name              = "prod-admin-service"
        enable_container_insights = true
        log_retention_days        = 30
        container_environment     = []
        container_secrets         = []
      }
    }
    alb = {
      internal          = false
      target_port       = 80
      listener_port     = 80
      health_check_path = "/"
      max_capacity      = 4
      min_capacity      = 1
      routes = {
        frontend = {
          path_pattern = "/*"
          priority     = 100
        }
        backend = {
          path_pattern = "/api/*"
          priority     = 200
        }
        admin = {
          path_pattern = "/admin/*"
          priority     = 300
        }
        grafana = {
          path_pattern = "/grafana/*"
          priority     = 400
        }
        sonar = {
          path_pattern = "/sonar/*"
          priority     = 500
        }
      }
    }
    security = {
      container_port = 80
      frontend_port  = 80
      ingress_rules = [
        {
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
      alb_ingress_rules = [
        {
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
    }
    domain_config = {
      domain_name = "boiler-plate.com"
    }
    monitoring_config = {
      enable_cloudwatch = true
      enable_xray       = true
    }
    tags = {
      Environment = "prod"
      Project     = "boiler-plate"
      ManagedBy   = "terraform"
      Owner       = "ProdTeam"
      Company     = "gabriel-boiler-plate"
    }

    # S3 Configuration for boiler-plate
    s3 = {
      buckets = {
        media = {
          name            = "boiler-plate-media"
          versioning      = true
          lifecycle_rules = []
        }
        static = {
          name            = "boiler-plate-static"
          versioning      = false
          lifecycle_rules = []
        }
        backups = {
          name       = "boiler-plate-backups"
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
          name            = "boiler-plate-configs"
          versioning      = true
          lifecycle_rules = []
        }
      }
    }

    # ElastiCache Redis Configuration
    elasticache = {
      node_type                = "cache.t3.micro"
      num_cache_nodes          = 1
      parameter_group_name     = "default.redis7"
      port                     = 6379
      engine_version           = "7.0"
      apply_immediately        = true
      maintenance_window       = "sun:05:00-sun:06:00"
      snapshot_retention_limit = 1
      snapshot_window          = "03:00-04:00"
    }

    # Monitoring Server Configuration
    monitoring = {
      instance_type = "t2.small"
      ami_id        = "ami-0d05471b100e9083f" # Amazon Linux 2 us-east-1
      key_name      = "boiler-plate-prod-key"
      services = {
        prometheus = {
          port = 9090
          path = "/prometheus"
        }
        grafana = {
          port = 3000
          path = "/grafana"
        }
        blackbox = {
          port = 9115
          path = "/blackbox"
        }
        sonarqube = {
          port = 9000
          path = "/sonar"
        }
      }
    }
  }

  # # QA Environment
  # qa = {
  #   environment = "qa"
  #   project_name = "terngiai"
  #   vpc = {
  #     cidr = "10.1.0.0/16"
  #     public_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  #     private_subnets = ["10.1.3.0/24", "10.1.4.0/24"]
  #     azs = ["us-east-1a", "us-east-1b"]
  #     single_nat_gateway = true
  #     enable_nat_gateway = true
  #     enable_dns_hostnames = true
  #     enable_dns_support = true
  #     enable_flow_log = true
  #     flow_log_retention_in_days = 14
  #   }
  #   rds = {
  #     instance_class = "db.t3.small"
  #     allocated_storage = 20
  #     max_allocated_storage = 100
  #     multi_az = false
  #     deletion_protection = false
  #     db_name = "terngiai_qa"
  #     backup_retention_period = 7
  #     backup_window = "03:00-04:00"
  #     maintenance_window = "Mon:04:00-Mon:05:00"
  #     engine = "postgres"
  #     engine_version = "14.10"
  #     port = 5432
  #     db_parameters = [
  #       {
  #         name = "max_connections"
  #         value = "100"
  #       },
  #       {
  #         name = "shared_buffers"
  #         value = "256MB"
  #       },
  #       {
  #         name = "work_mem"
  #         value = "4MB"
  #       }
  #     ]
  #     skip_final_snapshot = true
  #   }
  #   ec2 = {
  #     instance_type = "t3.small"
  #     ami_id = "ami-0c55b159cbfafe1f0"
  #     desired_capacity = 2
  #     min_size = 1
  #     max_size = 3
  #     key_name = "terngiai-qa-key"
  #   }
  #   ecs = {
  #     cluster_name = "qa-cluster"
  #     frontend = {
  #       task_cpu = 1024
  #       task_memory = 2048
  #       container_port = 80
  #       container_image = "nginx:latest"
  #       desired_count = 2
  #       container_name = "frontend"
  #       instance_type = "t3.medium"
  #       enable_container_insights = true
  #       log_retention_days = 14
  #       container_environment = []
  #       container_secrets = []
  #     }
  #     backend = {
  #       task_cpu = 512
  #       task_memory = 1024
  #       container_port = 8080
  #       container_image = "backend:latest"
  #       desired_count = 2
  #       enable_container_insights = true
  #       log_retention_days = 14
  #       container_environment = []
  #       container_secrets = []
  #     }
  #     api = {
  #       task_cpu = 512
  #       task_memory = 1024
  #       container_port = 3000
  #       container_image = "api:latest"
  #       desired_count = 2
  #       enable_container_insights = true
  #       log_retention_days = 14
  #       container_environment = []
  #       container_secrets = []
  #     }
  #     chat = {
  #       task_cpu = 512
  #       task_memory = 1024
  #       container_port = 3001
  #       container_image = "chat:latest"
  #       desired_count = 2
  #       enable_container_insights = true
  #       log_retention_days = 14
  #       container_environment = []
  #       container_secrets = []
  #     }
  #     ai = {
  #       task_cpu = 1024
  #       task_memory = 2048
  #       container_port = 3002
  #       container_image = "ai:latest"
  #       desired_count = 2
  #       enable_container_insights = true
  #       log_retention_days = 14
  #       container_environment = []
  #       container_secrets = []
  #     }
  #   }
  #   alb = {
  #     internal = false
  #     target_port = 80
  #     listener_port = 80
  #     health_check_path = "/"
  #     max_capacity = 3
  #     min_capacity = 1
  #   }
  #   security = {
  #     container_port = 80
  #     frontend_port = 80
  #     ingress_rules = [
  #       {
  #         from_port = 80
  #         to_port = 80
  #         protocol = "tcp"
  #         cidr_blocks = ["0.0.0.0/0"]
  #       }
  #     ]
  #     alb_ingress_rules = [
  #       {
  #         from_port = 80
  #         to_port = 80
  #         protocol = "tcp"
  #         cidr_blocks = ["0.0.0.0/0"]
  #       }
  #     ]
  #   }
  #   domain_config = {
  #     domain_name = "qa.terngiai.com"
  #   }
  #   monitoring_config = {
  #     enable_cloudwatch = true
  #     enable_xray = true
  #   }
  #   task_resources = {
  #     cpu = 256
  #     memory = 512
  #   }
  #   tags = {
  #     Environment = "qa"
  #     Project = "terngiai"
  #     ManagedBy = "terraform"
  #     Owner = "QATeam"
  #   }
  # }
} 