# Transit Gateway Root Module
# Uncomment to enable Transit Gateway for hub-and-spoke network architecture


module "transit_gateway" {
  source = "./transit_gateway"

  name        = "${local.project_name}-tgw"
  description = "Transit Gateway for connecting multiple VPCs"
  
  # BGP ASN
  amazon_side_asn = 64512
  
  # Default route table behavior
  default_route_table_association = "enable"  # Set to "disable" for custom routing
  default_route_table_propagation = "enable"  # Set to "disable" for custom routing
  
  # Features
  dns_support       = "enable"
  vpn_ecmp_support  = "enable"  # Load balance across VPN tunnels
  
  # VPC Attachments
  vpc_attachments = {
    main = {
      vpc_id     = module.vpc.vpc_id
      subnet_ids = module.vpc.private_subnet_ids
    }
    # Add more VPC attachments as needed
    # vpc2 = {
    #   vpc_id     = "vpc-xxxxxxxxx"
    #   subnet_ids = ["subnet-xxxxxx", "subnet-yyyyyy"]
    # }
  }
  
  # Routes in VPC route tables pointing to Transit Gateway
  vpc_route_table_routes = {
    main_to_tgw = {
      route_table_id         = module.vpc.private_route_table_ids[0]
      destination_cidr_block = "10.0.0.0/8"  # Route all 10.x traffic through TGW
    }
  }
  
  # Custom Route Tables (for network segmentation)
  # transit_gateway_route_tables = {
  #   production  = {}
  #   development = {}
  # }
  
  # Route Table Associations (for custom routing)
  # transit_gateway_route_table_associations = {
  #   main_to_prod = {
  #     vpc_attachment_id              = "main"
  #     transit_gateway_route_table_id = "production"
  #   }
  # }
  
  # Cross-Account Sharing (optional)
  enable_resource_sharing    = false
  allow_external_principals  = false
  # ram_principals = ["123456789012", "210987654321"]  # Account IDs to share with
  
  # Monitoring
  enable_monitoring = true
  enable_flow_logs  = true
  flow_logs_retention_days = 30
  
  alarm_actions = []  # Add SNS topic ARNs for alerts
  
  tags = local.tags
}

# Outputs
output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = try(module.transit_gateway.transit_gateway_id, null)
}

output "transit_gateway_arn" {
  description = "Transit Gateway ARN"
  value       = try(module.transit_gateway.transit_gateway_arn, null)
}

output "transit_gateway_attachment_ids" {
  description = "VPC attachment IDs"
  value       = try(module.transit_gateway.vpc_attachment_ids, null)
}

output "transit_gateway_route_table_ids" {
  description = "Transit Gateway route table IDs"
  value       = try(module.transit_gateway.transit_gateway_route_table_ids, null)
}

