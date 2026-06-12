module "vpc" {
  source = "./modules/vpc"

  environment = local.environment
  vpc_cidr    = local.current_env.vpc.cidr

  availability_zones   = local.current_env.vpc.azs
  public_subnet_cidrs  = local.current_env.vpc.public_subnets
  private_subnet_cidrs = local.current_env.vpc.private_subnets

  # NAT Gateway Configuration
  enable_nat_gateway = local.current_env.vpc.enable_nat_gateway
  single_nat_gateway = local.current_env.vpc.single_nat_gateway
  # one_nat_gateway_per_az = local.current_env.vpc.one_nat_gateway_per_az

  # Flow Log Configuration
  # enable_flow_log = local.environment.vpc.enable_flow_log
  # flow_log_retention_in_days = local.environment.vpc.flow_log_retention_in_days

  # Tags
  tags = local.tags
} 