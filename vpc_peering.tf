# VPC Peering Root Module
# Uncomment to enable VPC peering

module "vpc_peering" {
  source = "./vpc_peering"

  # Configure VPC peering
  requester_vpc_id     = module.vpc.vpc_id
  accepter_vpc_id      = "vpc-xxxxxxxxx"  # Update with target VPC ID
  requester_cidr_block = local.current_env.vpc.cidr
  accepter_cidr_block  = "10.1.0.0/16"    # Update with target VPC CIDR
  
  # Route table configuration
  requester_route_table_ids = module.vpc.private_route_table_ids
  accepter_route_table_ids  = ["rtb-xxxxxxxxx"]  # Update with target VPC route table IDs
  
  # Peering configuration
  auto_accept  = true  # Set to false for cross-account/cross-region
  peering_name = "${local.project_name}-vpc-peering"
  
  # DNS resolution
  requester_allow_remote_vpc_dns_resolution = true
  accepter_allow_remote_vpc_dns_resolution  = true
  
  # Optional: Create security group rules
  create_security_group_rules = false
  
  tags = local.tags
}

# Outputs
output "vpc_peering_connection_id" {
  description = "VPC peering connection ID"
  value       = try(module.vpc_peering.peering_connection_id, null)
}

output "vpc_peering_status" {
  description = "VPC peering connection status"
  value       = try(module.vpc_peering.peering_connection_status, null)
}
