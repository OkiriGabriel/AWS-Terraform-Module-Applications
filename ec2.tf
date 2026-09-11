# Production ECS capacity (ASG + launch template)
module "ec2" {
  count  = terraform.workspace == "infrastructure-prod" ? 1 : 0
  source = "./ec2"

  environment        = local.environment
  ami_id             = local.current_env.ec2.ami_id
  instance_type      = local.current_env.ec2.instance_type
  security_group_ids = [module.security_groups.ecs_instances_security_group_id]
  private_subnet_ids = module.vpc.private_subnet_ids
  ecs_cluster_name   = aws_ecs_cluster.main[0].name
  desired_capacity   = local.current_env.ec2.desired_capacity
  max_size           = local.current_env.ec2.max_size
  min_size           = local.current_env.ec2.min_size
  tags               = local.tags
}
