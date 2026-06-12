# boiler-plate ECS Cluster Configuration
# Single cluster with 3 services: Frontend, Backend API, Admin Dashboard

# Main ECS Cluster for all services (Production only)
resource "aws_ecs_cluster" "main" {
  count = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name  = "boiler-plate-prod-cluster" # Hardcoded since this only runs in prod

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.tags, {
    Name = "boiler-plate-prod-cluster" # Hardcoded since this only runs in prod
  })
}

# CloudWatch Log Groups for all services
resource "aws_cloudwatch_log_group" "frontend" {
  count             = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name              = "/ecs/${local.environment}-frontend"
  retention_in_days = 30 # Hardcoded since this only runs in prod
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "backend" {
  count             = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name              = "/ecs/${local.environment}-backend"
  retention_in_days = 30 # Hardcoded since this only runs in prod
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "admin" {
  count             = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name              = "/ecs/${local.environment}-admin"
  retention_in_days = 30 # Hardcoded since this only runs in prod
  tags              = local.tags
}