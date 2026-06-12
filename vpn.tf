  # VPN Root Module
# Uncomment to enable Site-to-Site VPN or Client VPN

# ============================================
# Site-to-Site VPN (Connect to On-Premises)
# ============================================

module "site_to_site_vpn" {
  source = "./vpn"

  name_prefix = "${local.project_name}-vpn"
  vpc_id      = module.vpc.vpc_id
  
  # Site-to-Site VPN Configuration
  create_site_to_site_vpn     = true
  customer_gateway_ip_address = "YOUR.PUBLIC.IP.ADDRESS"  # Update with your on-premises public IP
  customer_gateway_bgp_asn    = 65000
  amazon_side_asn             = 64512
  
  # Use Transit Gateway or Virtual Private Gateway
  use_transit_gateway = false  # Set to true if using Transit Gateway
  # transit_gateway_id = module.transit_gateway.transit_gateway_id  # Uncomment if using TGW
  
  # Route propagation (for VPN Gateway)
  route_table_ids = module.vpc.private_route_table_ids
  
  # Static routing (optional)
  static_routes_only = false  # Set to true for static routes
  # static_routes = ["10.0.0.0/8", "172.16.0.0/12"]
  
  # Tunnel configuration (optional)
  # tunnel1_preshared_key = var.tunnel1_psk  # Store in Secrets Manager
  # tunnel2_preshared_key = var.tunnel2_psk
  
  enable_monitoring = true
  alarm_actions     = []  # Add SNS topic ARNs for alerts
  
  tags = local.tags
}

# Outputs
output "vpn_connection_id" {
  description = "VPN connection ID"
  value       = try(module.site_to_site_vpn.vpn_connection_id, null)
}

output "vpn_tunnel1_address" {
  description = "VPN tunnel 1 public IP"
  value       = try(module.site_to_site_vpn.vpn_connection_tunnel1_address, null)
}

output "vpn_tunnel2_address" {
  description = "VPN tunnel 2 public IP"
  value       = try(module.site_to_site_vpn.vpn_connection_tunnel2_address, null)
}

# ============================================
# Client VPN (Remote User Access)
# ============================================
module "client_vpn" {
  source = "./vpn"

  name_prefix = "${local.project_name}-client-vpn"
  vpc_id      = module.vpc.vpc_id
  
  # Client VPN Configuration
  create_client_vpn = true
  
  # Certificates (must be created in ACM first)
  server_certificate_arn      = "arn:aws:acm:us-east-1:ACCOUNT:certificate/SERVER-CERT-ID"
  client_root_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CLIENT-CERT-ID"
  
  # Client configuration
  client_cidr_block   = "172.16.0.0/22"
  split_tunnel        = true
  transport_protocol  = "udp"
  vpn_port            = 443
  
  # Authentication
  authentication_type = "certificate-authentication"
  # For Active Directory: authentication_type = "directory-service-authentication"
  # active_directory_id = aws_directory_service_directory.main.id
  
  # Network associations
  client_vpn_subnet_ids         = module.vpc.private_subnet_ids
  client_vpn_security_group_ids = [module.security_groups.ecs_instances_security_group_id]
  
  # Authorization rules
  client_vpn_authorization_rules = [
    {
      target_network_cidr  = local.current_env.vpc.cidr
      authorize_all_groups = true
      description          = "Allow access to VPC"
    }
  ]
  
  # Routes
  client_vpn_routes = [
    {
      destination_cidr_block = local.current_env.vpc.cidr
      target_vpc_subnet_id   = module.vpc.private_subnet_ids[0]
      description            = "Route to VPC"
    }
  ]
  
  enable_connection_logging = true
  log_retention_days        = 30
  
  tags = local.tags
}

# Outputs
output "client_vpn_endpoint_id" {
  description = "Client VPN endpoint ID"
  value       = try(module.client_vpn.client_vpn_endpoint_id, null)
}

output "client_vpn_endpoint_dns" {
  description = "Client VPN endpoint DNS name"
  value       = try(module.client_vpn.client_vpn_endpoint_dns_name, null)
}
