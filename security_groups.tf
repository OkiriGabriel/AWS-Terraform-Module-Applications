module "security_groups" {
  source = "./modules/security_groups"

  environment    = local.environment
  vpc_id         = module.vpc.vpc_id
  container_port = try(local.current_env.ecs.frontend.container_port, 80)
  tags           = local.tags
} 