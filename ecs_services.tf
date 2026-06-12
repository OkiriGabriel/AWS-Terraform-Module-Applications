# boiler-plate ECS Services Configuration
# 3 services running on 1 shared cluster: Frontend, Backend API, Admin Dashboard

# Frontend Service (WordPress/WooCommerce) - Routes: / (Production only)
module "ecs_frontend_service" {
  count  = terraform.workspace == "infrastructure-prod" ? 1 : 0
  source = "./ecs_service"

  environment  = local.environment
  cluster_id   = aws_ecs_cluster.main[0].id
  service_name = "${local.environment}-frontend-service"

  # Task Configuration
  task_cpu           = local.ecs.frontend.task_cpu
  task_memory        = local.ecs.frontend.task_memory
  desired_count      = local.ecs.frontend.desired_count
  min_capacity       = local.ecs.frontend.min_capacity
  max_capacity       = local.ecs.frontend.max_capacity
  log_group_name     = aws_cloudwatch_log_group.frontend[0].name
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.ecs_tasks_security_group_id]
  target_group_arn   = aws_lb_target_group.frontend[0].arn

  # Container Configuration
  container_name        = local.ecs.frontend.container_name
  container_image       = "${aws_ecr_repository.frontend.repository_url}:latest"
  container_port        = local.ecs.frontend.container_port
  container_environment = local.ecs.frontend.container_environment
  container_secrets     = local.ecs.frontend.container_secrets

  # EFS Configuration for WordPress shared storage    
  efs_file_system_id = terraform.workspace == "infrastructure-prod" ? aws_efs_file_system.wordpress[0].id : ""
  efs_volume_name    = "wordpress_efs"
  efs_container_path = "/wordpress"
  efs_read_only      = false

  tags = merge(local.tags, {
    Service = "Frontend"
  })

  depends_on = [aws_ecs_cluster.main, aws_lb_target_group.frontend]
}

# Backend API Service (REST API) - Routes: /api/* (Production only)
module "ecs_backend_service" {
  count  = terraform.workspace == "infrastructure-prod" ? 1 : 0
  source = "./ecs_service"

  environment  = local.environment
  cluster_id   = aws_ecs_cluster.main[0].id
  service_name = "${local.environment}-backend-service"

  # Task Configuration
  task_cpu      = local.ecs.backend.task_cpu
  task_memory   = local.ecs.backend.task_memory
  desired_count = local.ecs.backend.desired_count
  min_capacity  = local.ecs.backend.min_capacity
  max_capacity  = local.ecs.backend.max_capacity

  # Container Configuration
  container_name        = local.ecs.backend.container_name
  container_image       = "${aws_ecr_repository.backend.repository_url}:latest"
  container_port        = local.ecs.backend.container_port
  container_environment = local.ecs.backend.container_environment
  container_secrets     = local.ecs.backend.container_secrets

  # Network Configuration
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.ecs_tasks_security_group_id]

  # Load Balancer
  target_group_arn = aws_lb_target_group.backend[0].arn

  # Logging
  log_group_name = aws_cloudwatch_log_group.backend[0].name

  tags = merge(local.tags, {
    Service = "Backend"
  })

  depends_on = [aws_ecs_cluster.main, aws_lb_target_group.backend]
}

# Admin Dashboard Service - Routes: /admin/* (Production only)
module "ecs_admin_service" {
  count  = terraform.workspace == "infrastructure-prod" ? 1 : 0
  source = "./ecs_service"

  environment  = local.environment
  cluster_id   = aws_ecs_cluster.main[0].id
  service_name = "${local.environment}-admin-service"

  # Task Configuration
  task_cpu      = local.ecs.admin.task_cpu
  task_memory   = local.ecs.admin.task_memory
  desired_count = local.ecs.admin.desired_count
  min_capacity  = local.ecs.admin.min_capacity
  max_capacity  = local.ecs.admin.max_capacity

  # Container Configuration
  container_name        = local.ecs.admin.container_name
  container_image       = "${aws_ecr_repository.admin.repository_url}:latest"
  container_port        = local.ecs.admin.container_port
  container_environment = local.ecs.admin.container_environment
  container_secrets     = local.ecs.admin.container_secrets

  # Network Configuration
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.ecs_tasks_security_group_id]

  # Load Balancer
  target_group_arn = aws_lb_target_group.admin[0].arn

  # Logging
  log_group_name = aws_cloudwatch_log_group.admin[0].name

  tags = merge(local.tags, {
    Service = "Admin"
  })

  depends_on = [aws_ecs_cluster.main, aws_lb_target_group.admin]
}