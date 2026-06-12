# Monitoring Server Configuration for boiler-plate
# Single EC2 (ASG min=1) running Prometheus, Grafana, Blackbox, SonarQube.
# Prod: private subnets + Grafana/Sonar via ALB SG. Dev: public subnets + public IP + open SG (no ALB).

locals {
  monitoring_enabled = contains(["infrastructure", "infrastructure-prod"], terraform.workspace)
}

module "monitoring_server" {
  count  = local.monitoring_enabled ? 1 : 0
  source = "./modules/monitoring"

  environment = local.environment
  vpc_id      = module.vpc.vpc_id

  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  instance_type = local.current_env.monitoring.instance_type
  ami_id        = local.current_env.monitoring.ami_id
  key_name      = local.current_env.monitoring.key_name

  services = local.current_env.monitoring.services

  # Dev has no ALB: monitoring runs in public subnets with a public IP and open SG. Prod stays private + ALB paths.
  use_public_ip = terraform.workspace == "infrastructure"

  alb_security_group_id = module.security_groups.alb_security_group_id

  tags = merge(local.tags, {
    Purpose = "Monitoring"
    Type    = "Infrastructure"
  })
}
