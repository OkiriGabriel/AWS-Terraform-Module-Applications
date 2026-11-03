# Web + API on ECS with Postgres, Redis and uploads bucket. HTTPS certificate and DNS record are created
# automatically from the hosted zone. Services receive DB_*, REDIS_* and BUCKET_* without any wiring.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.70.0, < 6.0.0" }
  }

  # backend "s3" { bucket = "my-tf-state", key = "acme/prod.tfstate", region = "us-east-1", use_lockfile = true }
}

provider "aws" {
  region = "us-east-1"
}

module "platform" {
  source = "../../"

  name        = "acme"
  environment = "prod"
  profile     = "production"
  stack       = ["ecs", "rds", "redis"]

  domain = {
    name    = "app.example.com"
    zone_id = "Z0123456789ABCDEFGHIJ" # Route 53 hosted zone for example.com
  }

  services = {
    web = {
      port          = 3000
      cpu           = 512
      memory        = 1024
      desired_count = 2
      max_count     = 10
    }
    api = {
      port              = 8080
      path_patterns     = ["/api/*"]
      health_check_path = "/api/health"
      desired_count     = 2
      environment       = { LOG_LEVEL = "info" }
    }
  }

  buckets = {
    uploads = {}
  }

  alert_email       = "oncall@example.com"
  github_repository = "acme/app" # the application repo whose main branch deploys

  # Any profile default can be changed without forking:
  overrides = {
    rds_instance_class = "db.t4g.large"
  }
}

output "summary" {
  value = module.platform.summary
}
