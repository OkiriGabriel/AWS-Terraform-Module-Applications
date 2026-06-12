module "rds" {
  count  = terraform.workspace == "infrastructure-prod" ? 1 : 0
  source = "./rds"

  environment             = local.environment
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  allowed_security_groups = [module.security_groups.ecs_tasks_security_group_id]

  instance_class          = local.current_env.rds.instance_class
  allocated_storage       = local.current_env.rds.allocated_storage
  max_allocated_storage   = local.current_env.rds.max_allocated_storage
  db_name                 = local.current_env.rds.db_name
  security_group_id       = module.security_groups.ecs_tasks_security_group_id
  db_username             = module.db_secrets[0].username
  db_password             = module.db_secrets[0].password
  db_parameters           = local.current_env.rds.db_parameters
  backup_retention_period = local.current_env.rds.backup_retention_period
  backup_window           = local.current_env.rds.backup_window
  maintenance_window      = local.current_env.rds.maintenance_window
  skip_final_snapshot     = local.current_env.rds.skip_final_snapshot
  deletion_protection     = local.current_env.rds.deletion_protection
  multi_az                = local.current_env.rds.multi_az

  tags = local.tags
}

resource "random_string" "rds_username" {
  count   = terraform.workspace == "infrastructure-prod" ? 1 : 0
  length  = 16
  special = false
  upper   = false
}

resource "random_password" "rds_password" {
  count   = terraform.workspace == "infrastructure-prod" ? 1 : 0
  length  = 32
  special = false
} 