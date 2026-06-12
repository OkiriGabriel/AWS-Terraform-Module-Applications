# ElastiCache Redis Configuration for boiler-plate
module "elasticache" {
  count  = terraform.workspace == "infrastructure-prod" ? 1 : 0
  source = "./elasticache"

  environment = local.environment
  vpc_id      = module.vpc.vpc_id

  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.ecs_tasks_security_group_id]

  node_type                = local.current_env.elasticache.node_type
  num_cache_nodes          = local.current_env.elasticache.num_cache_nodes
  parameter_group_name     = local.current_env.elasticache.parameter_group_name
  port                     = local.current_env.elasticache.port
  engine_version           = local.current_env.elasticache.engine_version
  apply_immediately        = local.current_env.elasticache.apply_immediately
  maintenance_window       = local.current_env.elasticache.maintenance_window
  snapshot_retention_limit = local.current_env.elasticache.snapshot_retention_limit
  snapshot_window          = local.current_env.elasticache.snapshot_window

  tags = local.tags
}