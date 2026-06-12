# Infrastructure Outputs for boiler-plate
# Key infrastructure information for operations and CI/CD

# Load Balancer Information
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = terraform.workspace == "infrastructure-prod" ? aws_lb.main[0].dns_name : "N/A - Dev uses EC2"
}

# Development EC2 Information
output "dev_servers" {
  description = "Development EC2 server information"
  value = terraform.workspace == "infrastructure" ? {
    frontend = {
      instance_id = aws_instance.frontend_dev[0].id
      public_ip   = aws_instance.frontend_dev[0].public_ip
      private_ip  = aws_instance.frontend_dev[0].private_ip
      dns_name    = aws_instance.frontend_dev[0].public_dns
    }
    backend = {
      instance_id = aws_instance.backend_dev[0].id
      public_ip   = aws_instance.backend_dev[0].public_ip
      private_ip  = aws_instance.backend_dev[0].private_ip
      dns_name    = aws_instance.backend_dev[0].public_dns
    }
    } : {
    frontend = {
      instance_id = "N/A - Production uses ECS"
      public_ip   = "N/A - Production uses ECS"
      private_ip  = "N/A - Production uses ECS"
      dns_name    = "N/A - Production uses ECS"
    }
    backend = {
      instance_id = "N/A - Production uses ECS"
      public_ip   = "N/A - Production uses ECS"
      private_ip  = "N/A - Production uses ECS"
      dns_name    = "N/A - Production uses ECS"
    }
  }
}

output "alb_hosted_zone_id" {
  description = "Hosted zone ID for the ALB (for Route53 aliases)"
  value       = terraform.workspace == "infrastructure-prod" ? aws_lb.main[0].zone_id : "N/A - Dev uses EC2"
}

# ECR Repository URLs
output "ecr_repositories" {
  description = "ECR repository URLs for CI/CD pipelines"
  value = terraform.workspace == "infrastructure-prod" ? {
    frontend = aws_ecr_repository.frontend.repository_url
    backend  = aws_ecr_repository.backend.repository_url
    admin    = aws_ecr_repository.admin.repository_url
    } : {
    frontend = "N/A - Dev uses local images"
    backend  = "N/A - Dev uses local images"
    admin    = "N/A - Dev uses local images"
  }
}

# ECS Cluster Information
output "ecs_cluster" {
  description = "ECS cluster information"
  value = terraform.workspace == "infrastructure-prod" ? {
    name = aws_ecs_cluster.main[0].name
    arn  = aws_ecs_cluster.main[0].arn
    } : {
    name = "N/A - Dev uses EC2 instances"
    arn  = "N/A - Dev uses EC2 instances"
  }
}

# Database Information
output "database_endpoint" {
  description = "RDS database endpoint"
  value       = terraform.workspace == "infrastructure-prod" ? module.rds[0].db_instance_endpoint : "localhost:3306 - Local MySQL in dev"
  sensitive   = true
}

# Redis Information
output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = terraform.workspace == "infrastructure-prod" ? module.elasticache[0].redis_endpoint : "localhost:6379 - Local Redis in dev"
  sensitive   = true
}

# EFS Information
output "efs_file_system" {
  description = "EFS file system information for WordPress"
  value = terraform.workspace == "infrastructure-prod" ? {
    id              = aws_efs_file_system.wordpress[0].id
    dns_name        = aws_efs_file_system.wordpress[0].dns_name
    access_point_id = aws_efs_access_point.wordpress[0].id
    } : {
    id              = "N/A - Dev uses local storage"
    dns_name        = "N/A - Dev uses local storage"
    access_point_id = "N/A - Dev uses local storage"
  }
}

# S3 Bucket Information
output "s3_buckets" {
  description = "S3 bucket information"
  value = {
    media   = module.s3_media.bucket_id
    static  = module.s3_static.bucket_id
    backups = module.s3_backups.bucket_id
    configs = module.s3_configs.bucket_id
  }
}

# CloudFront (static assets) — same module wiring for dev and prod workspaces
# CloudFront static is optional - uncomment when cloudfront_static module is enabled
# output "cloudfront_static" {
#   description = "CloudFront CDN for the static-assets S3 bucket"
#   value = {
#     domain_name      = module.cloudfront_static.domain_name
#     distribution_id  = module.cloudfront_static.distribution_id
#     distribution_arn = module.cloudfront_static.distribution_arn
#     url              = "https://${module.cloudfront_static.domain_name}"
#   }
# }

# Security Information
output "security_groups" {
  description = "Security group IDs"
  value = {
    alb_sg       = module.security_groups.alb_security_group_id
    ecs_tasks_sg = module.security_groups.ecs_tasks_security_group_id
    efs_sg       = terraform.workspace == "infrastructure-prod" ? aws_security_group.efs[0].id : "N/A - Dev environment"
  }
}

# Monitoring Information
output "monitoring_endpoints" {
  description = "Monitoring service endpoints"
  value = {
    grafana = terraform.workspace == "infrastructure-prod" ? "https://${aws_lb.main[0].dns_name}/grafana/" : (
      terraform.workspace == "infrastructure" ? "http://INSTANCE_PUBLIC_IP:3000/grafana/ (see ASG ${module.monitoring_server[0].autoscaling_group_name} in EC2 console)" : "N/A"
    )
    sonarqube = terraform.workspace == "infrastructure-prod" ? "https://${aws_lb.main[0].dns_name}/sonar/" : (
      terraform.workspace == "infrastructure" ? "http://INSTANCE_PUBLIC_IP:9000/sonar/ (same instance as Grafana)" : "N/A"
    )
    prometheus = terraform.workspace == "infrastructure" ? "http://INSTANCE_PUBLIC_IP:9090" : (
      terraform.workspace == "infrastructure-prod" ? "internal VPC :9090" : "N/A"
    )
  }
}

# GitHub Actions role is optional (see commented block in ecr_cicd.tf).
output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions CI/CD when that resource is enabled"
  value       = "Not managed — enable aws_iam_role.github_actions in ecr_cicd.tf to use OIDC push/deploy"
}

# Backup Information
output "backup_vault" {
  description = "AWS Backup vault information"
  value = {
    name = aws_backup_vault.example.name
    arn  = aws_backup_vault.example.arn
  }
}

# WAF Information
output "waf_web_acl" {
  description = "WAF Web ACL information"
  value = terraform.workspace == "infrastructure-prod" ? {
    name = aws_wafv2_web_acl.example[0].name
    arn  = aws_wafv2_web_acl.example[0].arn
    } : {
    name = "N/A - Dev environment"
    arn  = "N/A - Dev environment"
  }
}

# Cost Estimation Information
output "cost_estimation" {
  description = "Estimated monthly costs by component"
  value = {
    environment            = local.environment
    estimated_monthly_cost = local.environment == "dev" ? "$42" : "$100"
    scaling_path = {
      "500_revenue"  = "Add 2nd NAT Gateway (+$16)"
      "1000_revenue" = "Enable RDS Multi-AZ (+$15)"
      "1500_revenue" = "Add Redis replica (+$13)"
      "2000_revenue" = "Enable detailed monitoring (+$5)"
    }
  }
}