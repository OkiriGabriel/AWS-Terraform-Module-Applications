# ============================================
# WHAT YOU GOT
# ============================================

locals {
  url = !local.has.ecs ? null : (
    var.domain != null ? "${local.https ? "https" : "http"}://${var.domain.name}" : "http://${aws_lb.main[0].dns_name}"
  )

  # --- Rough monthly cost (us-east-1 on-demand list prices, 730 h; excludes data transfer and usage-billed services)
  price = {
    nat_hour      = 0.045
    alb_month     = 22.0 # hours + ~1 LCU
    fargate_vcpu  = 29.55
    fargate_gb    = 3.24
    spot_discount = 0.3
    rds_gb        = 0.115
    eks_control   = 73.0
    waf_month     = 11.0
    vpn_month     = 36.5
    cvpn_assoc    = 73.0
    tgw_attach    = 36.5
    endpoint_az   = 7.3
    kms_key       = 1.0
    rds_class = {
      "db.t4g.micro" = 11.68, "db.t4g.small" = 23.36, "db.t4g.medium" = 47.45, "db.t4g.large" = 94.17,
      "db.m7g.large" = 122.64, "db.m7g.xlarge" = 245.28, "db.r7g.large" = 174.47, "db.r7g.xlarge" = 348.94
    }
    redis_node = {
      "cache.t4g.micro" = 11.68, "cache.t4g.small" = 23.36, "cache.t4g.medium" = 47.45,
      "cache.m7g.large" = 115.34, "cache.r7g.large" = 159.14
    }
    eks_node = { "t3.medium" = 30.37, "t3.large" = 60.74, "m7i.large" = 73.58, "m7g.large" = 59.57 }
  }

  nat_count = local.s.nat_mode == "none" ? 0 : (local.s.nat_mode == "single" ? 1 : local.az_count)

  cost = { for k, v in {
    nat_gateways  = local.nat_count * local.price.nat_hour * 730
    load_balancer = local.has.ecs ? local.price.alb_month : 0
    ecs_services = sum(concat([0], [for s in local.services :
      (s.cpu / 1024 * local.price.fargate_vcpu + s.memory / 1024 * local.price.fargate_gb) * s.desired_count *
      (local.s.ecs_capacity == "FARGATE_SPOT" ? local.price.spot_discount : 1)
    ]))
    rds              = local.has.rds ? (lookup(local.price.rds_class, local.s.rds_instance_class, 0) + local.s.rds_storage_gb * local.price.rds_gb) * (local.s.rds_multi_az ? 2 : 1) : 0
    redis            = local.has.redis ? lookup(local.price.redis_node, local.s.redis_node_type, 0) * local.s.redis_nodes : 0
    eks              = local.has.eks ? local.price.eks_control + lookup(local.price.eks_node, var.eks.instance_types[0], 0) * var.eks.desired_size * (var.profile == "starter" ? local.price.spot_discount : 1) : 0
    waf              = local.waf_enabled ? local.price.waf_month : 0
    site_to_site_vpn = local.has.vpn ? local.price.vpn_month : 0
    client_vpn       = local.has.client_vpn ? local.price.cvpn_assoc * local.az_count : 0
    transit_gateway  = local.has.transit_gateway ? local.price.tgw_attach : 0
    vpc_endpoints    = local.s.interface_endpoints ? local.price.endpoint_az * local.az_count * 9 : 0
    kms_keys         = (local.s.kms_cmk ? 1 : 0) + (local.baseline.cloudtrail ? 1 : 0)
  } : k => ceil(v) if v > 0 }

  unpriced = compact([
    local.has.rds && !contains(keys(local.price.rds_class), local.s.rds_instance_class) ? "rds (${local.s.rds_instance_class})" : "",
    local.has.redis && !contains(keys(local.price.redis_node), local.s.redis_node_type) ? "redis (${local.s.redis_node_type})" : "",
  ])

  next_steps = compact([
    var.alert_email != "" ? "Confirm the SNS subscription email sent to ${var.alert_email}." : "Set alert_email so alarms and security findings reach someone.",
    local.has.ecs && anytrue([for s in local.services : s.image == null]) ? "Push images: aws ecr get-login-password | docker login ...; then docker push <ecr_repositories[service]>:latest" : "",
    local.has.ecs && var.domain != null && try(var.domain.zone_id, null) == null ? "Create a DNS record: ${try(var.domain.name, "")} CNAME ${aws_lb.main[0].dns_name}" : "",
    local.has.ecs && !local.https ? "Traffic is plain HTTP. Add domain = { name, zone_id } to get HTTPS automatically." : "",
    local.has.eks ? "kubectl access: aws eks update-kubeconfig --name ${local.prefix} --region ${local.region}" : "",
    local.has.vpn ? "Download the tunnel config for your router: VPC console > Site-to-Site VPN > ${module.site_to_site_vpn[0].vpn_connection_id} > Download configuration." : "",
    local.has.client_vpn ? "Export the client profile: aws ec2 export-client-vpn-client-configuration --client-vpn-endpoint-id ${module.client_vpn[0].client_vpn_endpoint_id} --output text > ${local.prefix}.ovpn" : "",
    local.github_oidc ? "Add repo secret AWS_DEPLOY_ROLE_ARN = ${aws_iam_role.github_deploy[0].arn}" : "",
    !var.account_baseline ? "account_baseline = false: make sure GuardDuty, CloudTrail, Config and Security Hub are managed elsewhere (e.g. organization level)." : "",
  ])
}

output "summary" {
  description = "Human-readable summary of what this module created."
  value = {
    name      = local.prefix
    profile   = var.profile
    region    = local.region
    stack     = sort(tolist(var.stack))
    url       = local.url
    dashboard = length(aws_cloudwatch_dashboard.main) > 0 ? "https://${local.region}.console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards/dashboard/${local.prefix}" : null
    services  = keys(local.services)
    network   = "${local.vpc_cidr} across ${local.az_count} AZs, NAT: ${local.s.nat_mode}${local.s.interface_endpoints ? ", private AWS endpoints" : ""}"
    security = compact([
      local.https ? "HTTPS (TLS 1.3/1.2) with HTTP redirect" : "HTTP only (no domain configured)",
      local.waf_enabled ? "WAF: managed rules + rate limit ${local.s.waf_rate_limit}/5min/IP" : "",
      local.s.kms_cmk ? "Customer-managed KMS on all data stores and logs" : "AWS-managed encryption on all data stores",
      local.baseline.guardduty ? "GuardDuty" : "",
      local.baseline.inspector ? "Inspector (EC2/ECR/Lambda)" : "",
      local.baseline.security_hub ? "Security Hub (FSBP + CIS v3.0)" : "",
      local.baseline.aws_config ? "AWS Config recorder" : "",
      local.baseline.cloudtrail ? "CloudTrail (multi-region, validated, ${local.s.audit_log_retention}d)" : "",
      local.baseline.cis_alarms ? "${length(local.cis_metric_filters)} CIS alarms" : "",
      local.s.backup ? "AWS Backup ${local.s.backup_daily_days}d daily${local.s.backup_vault_lock ? ", vault lock" : ""}" : "",
    ])
    estimated_monthly_usd = {
      total        = sum(concat([0], values(local.cost)))
      by_component = local.cost
      note         = "List-price estimate (us-east-1, on-demand, 730h). Excludes data transfer and usage-billed services (GuardDuty, Config, Security Hub, logs, S3, EFS, CloudFront).${length(local.unpriced) > 0 ? " Not priced: ${join(", ", local.unpriced)}." : ""}"
    }
    next_steps = local.next_steps
  }
}

output "settings" {
  description = "Fully resolved profile settings (profile defaults + overrides). Any key can be overridden."
  value       = local.s
}

# --------------------------------------------
# Building blocks (for wiring other stacks to this one)
# --------------------------------------------
output "vpc" {
  description = "VPC identifiers"
  value = {
    id                      = module.vpc.vpc_id
    cidr                    = module.vpc.vpc_cidr_block
    public_subnet_ids       = module.vpc.public_subnet_ids
    private_subnet_ids      = module.vpc.private_subnet_ids
    private_route_table_ids = module.vpc.private_route_table_ids
    nat_public_ips          = module.vpc.nat_public_ips
  }
}

output "security_group_ids" {
  description = "Security groups to reference from other stacks"
  value = {
    alb   = module.security_groups.alb_security_group_id
    tasks = module.security_groups.tasks_security_group_id
  }
}

output "load_balancer" {
  description = "ALB details (null without ecs)"
  value = local.has.ecs ? {
    dns_name = aws_lb.main[0].dns_name
    zone_id  = aws_lb.main[0].zone_id
    arn      = aws_lb.main[0].arn
  } : null
}

output "ecs" {
  description = "ECS cluster and services"
  value = local.has.ecs ? {
    cluster_name = aws_ecs_cluster.main[0].name
    services     = { for k, m in module.ecs_service : k => m.service_name }
    task_roles   = { for k, m in module.ecs_service : k => m.task_role_arn }
  } : null
}

output "ecr_repositories" {
  description = "ECR repository URLs per service"
  value       = { for k, r in aws_ecr_repository.service : k => r.repository_url }
}

output "database" {
  description = "RDS connection details (credentials live in Secrets Manager)"
  value = local.has.rds ? {
    endpoint   = module.rds[0].endpoint
    address    = module.rds[0].address
    port       = module.rds[0].port
    name       = module.rds[0].db_name
    secret_arn = module.rds[0].master_user_secret_arn
  } : null
}

output "redis" {
  description = "Redis connection details (TLS required; AUTH token in Secrets Manager)"
  value = local.has.redis ? {
    primary_endpoint = module.redis[0].primary_endpoint
    reader_endpoint  = module.redis[0].reader_endpoint
    port             = 6379
    auth_secret_arn  = module.redis[0].auth_secret_arn
  } : null
}

output "efs" {
  description = "Shared EFS file system"
  value       = local.has.efs ? { id = aws_efs_file_system.shared[0].id, access_point_id = aws_efs_access_point.shared[0].id } : null
}

output "buckets" {
  description = "Application bucket names"
  value       = { for k, b in module.app_bucket : k => b.bucket_id }
}

output "cdn" {
  description = "CloudFront distribution and its static bucket"
  value = local.has.cdn ? {
    domain_name     = module.cdn[0].domain_name
    distribution_id = module.cdn[0].distribution_id
    bucket          = module.static_bucket[0].bucket_id
  } : null
}

output "eks" {
  description = "EKS cluster"
  value = local.has.eks ? {
    name              = module.eks[0].cluster_name
    endpoint          = module.eks[0].cluster_endpoint
    oidc_provider_arn = module.eks[0].oidc_provider_arn
  } : null
}

output "connectivity" {
  description = "VPN, Client VPN, Transit Gateway and peering IDs"
  value = {
    site_to_site_vpn_id = try(module.site_to_site_vpn[0].vpn_connection_id, null)
    vpn_tunnel_ips      = local.has.vpn ? [module.site_to_site_vpn[0].vpn_connection_tunnel1_address, module.site_to_site_vpn[0].vpn_connection_tunnel2_address] : null
    client_vpn_endpoint = try(module.client_vpn[0].client_vpn_endpoint_id, null)
    transit_gateway_id  = try(module.transit_gateway[0].transit_gateway_id, null)
    peering_ids         = { for k, p in module.vpc_peering : k => p.peering_connection_id }
  }
}

output "alerts_topic_arn" {
  description = "SNS topic receiving all alarms (subscribe more endpoints here)"
  value       = aws_sns_topic.alerts.arn
}

output "github_deploy_role_arn" {
  description = "Role for aws-actions/configure-aws-credentials (null when github_repository is empty)"
  value       = try(aws_iam_role.github_deploy[0].arn, null)
}

output "kms_key_arn" {
  description = "Platform customer-managed KMS key (null unless kms_cmk)"
  value       = local.kms_key_arn
}
