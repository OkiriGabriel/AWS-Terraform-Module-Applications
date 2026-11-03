# ============================================
# NETWORK
# ============================================

module "vpc" {
  source = "./modules/vpc"

  name                 = local.prefix
  vpc_cidr             = local.vpc_cidr
  availability_zones   = local.azs
  public_subnet_cidrs  = local.public_subnets
  private_subnet_cidrs = local.private_subnets

  nat_mode                   = local.s.nat_mode
  enable_interface_endpoints = local.s.interface_endpoints
  flow_log_retention_days    = local.s.flow_log_retention
  kms_key_arn                = local.kms_key_arn

  tags = local.tags
}

module "security_groups" {
  source = "./modules/security_groups"

  name          = local.prefix
  vpc_id        = module.vpc.vpc_id
  service_ports = local.has.ecs ? distinct([for s in var.services : s.port]) : []
  tags          = local.tags
}
