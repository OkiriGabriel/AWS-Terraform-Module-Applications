# Examples of how to use the new modules
# Uncomment the modules you want to deploy

# ============================================
# EKS Cluster (Kubernetes)
# ============================================
/*
module "eks" {
  source = "./eks"

  cluster_name    = "${local.project_name}-eks-cluster"
  cluster_version = "1.28"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  node_groups = {
    general = {
      desired_size   = 2
      min_size       = 1
      max_size       = 4
      instance_types = ["t3.medium"]
    }
  }
  
  enable_irsa               = true
  enable_encryption         = true
  enable_container_insights = true
  
  tags = local.tags
}
*/

# ============================================
# GuardDuty (Threat Detection)
# ============================================
/*
module "guardduty" {
  source = "./guardduty"

  name_prefix = "${local.project_name}-guardduty"
  
  enable                       = true
  enable_s3_protection         = true
  enable_kubernetes_protection = true
  enable_malware_protection    = true
  
  enable_notifications = true
  notification_emails  = ["security@example.com"]  # Change this to your email
  minimum_severity_level = 4.0  # Only alert on Medium severity and above
  
  enable_findings_export = true
  enable_cloudwatch_logs = true
  
  tags = local.tags
}
*/

# ============================================
# Inspector (Vulnerability Scanning)
# ============================================
/*
module "inspector" {
  source = "./inspector"

  name_prefix = "${local.project_name}-inspector"
  
  resource_types = ["EC2", "ECR", "LAMBDA"]
  
  enable_notifications = true
  notification_emails  = ["security@example.com"]  # Change this to your email
  severity_filter      = ["CRITICAL", "HIGH"]
  
  enable_cloudwatch_logs = true
  enable_report_export   = true
  
  tags = local.tags
}
*/

# ============================================
# VPC Peering (Connect Multiple VPCs)
# ============================================
/*
# Example: Peer with another VPC
module "vpc_peering" {
  source = "./vpc_peering"

  requester_vpc_id     = module.vpc.vpc_id
  accepter_vpc_id      = "vpc-xxxxxxxxx"  # Your other VPC ID
  requester_cidr_block = local.current_env.vpc.cidr
  accepter_cidr_block  = "10.1.0.0/16"    # Other VPC CIDR
  
  requester_route_table_ids = module.vpc.private_route_table_ids
  accepter_route_table_ids  = ["rtb-xxxxxxxxx"]  # Other VPC route tables
  
  auto_accept  = true
  peering_name = "${local.project_name}-peering"
  
  tags = local.tags
}
*/

# ============================================
# Site-to-Site VPN (Connect to On-Premises)
# ============================================
/*
module "site_to_site_vpn" {
  source = "./vpn"

  name_prefix = "${local.project_name}-vpn"
  vpc_id      = module.vpc.vpc_id
  
  create_site_to_site_vpn     = true
  customer_gateway_ip_address = "YOUR.PUBLIC.IP.ADDRESS"  # Your on-premises public IP
  customer_gateway_bgp_asn    = 65000
  
  route_table_ids = module.vpc.private_route_table_ids
  
  enable_monitoring = true
  
  tags = local.tags
}
*/

# ============================================
# Client VPN (Remote User Access)
# ============================================
/*
module "client_vpn" {
  source = "./vpn"

  name_prefix = "${local.project_name}-client-vpn"
  vpc_id      = module.vpc.vpc_id
  
  create_client_vpn = true
  
  # You'll need to create and upload certificates to ACM first
  server_certificate_arn      = "arn:aws:acm:us-east-1:ACCOUNT:certificate/SERVER-CERT-ID"
  client_root_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CLIENT-CERT-ID"
  
  client_cidr_block = "172.16.0.0/22"
  split_tunnel      = true
  
  authentication_type = "certificate-authentication"
  
  client_vpn_subnet_ids         = module.vpc.private_subnet_ids
  client_vpn_security_group_ids = [module.security_groups.ecs_instances_security_group_id]
  
  # Allow access to VPC CIDR
  client_vpn_authorization_rules = [
    {
      target_network_cidr  = local.current_env.vpc.cidr
      authorize_all_groups = true
      description          = "Allow access to VPC"
    }
  ]
  
  # Route traffic to VPC
  client_vpn_routes = [
    {
      destination_cidr_block = local.current_env.vpc.cidr
      target_vpc_subnet_id   = module.vpc.private_subnet_ids[0]
      description            = "Route to VPC"
    }
  ]
  
  enable_connection_logging = true
  
  tags = local.tags
}
*/

# ============================================
# Transit Gateway (Hub-and-Spoke Network)
# ============================================
/*
module "transit_gateway" {
  source = "./transit_gateway"

  name        = "${local.project_name}-tgw"
  description = "Transit Gateway for connecting multiple VPCs"
  
  amazon_side_asn = 64512
  
  # Attach current VPC
  vpc_attachments = {
    main = {
      vpc_id     = module.vpc.vpc_id
      subnet_ids = module.vpc.private_subnet_ids
    }
    # Add more VPC attachments as needed
  }
  
  # Add routes in VPC route tables pointing to TGW
  vpc_route_table_routes = {
    main_to_tgw = {
      route_table_id         = module.vpc.private_route_table_ids[0]
      destination_cidr_block = "10.0.0.0/8"  # Route all 10.x traffic through TGW
    }
  }
  
  enable_monitoring = true
  enable_flow_logs  = true
  
  tags = local.tags
}
*/

# ============================================
# Complete Security Suite (All Security Modules)
# ============================================
/*
# Uncomment this section to enable all security features at once

module "guardduty" {
  source = "./guardduty"
  name_prefix = "${local.project_name}-guardduty"
  enable_notifications = true
  notification_emails = ["security@example.com"]
  tags = local.tags
}

module "inspector" {
  source = "./inspector"
  name_prefix = "${local.project_name}-inspector"
  resource_types = ["EC2", "ECR", "LAMBDA"]
  enable_notifications = true
  notification_emails = ["security@example.com"]
  tags = local.tags
}
*/
