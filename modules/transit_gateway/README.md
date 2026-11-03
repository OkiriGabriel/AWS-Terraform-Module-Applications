# Transit Gateway Module

This module creates an AWS Transit Gateway with a hub-and-spoke network architecture for connecting multiple VPCs, VPNs, and on-premises networks.

## Features

- Transit Gateway with customizable ASN
- VPC attachments with flexible routing
- Custom route tables and associations
- Static and dynamic routing
- Cross-account sharing via Resource Access Manager (RAM)
- Cross-region peering
- VPC Flow Logs
- CloudWatch monitoring and alarms
- Support for VPN ECMP (Equal Cost Multipath)
- Appliance mode for network appliances

## Use Cases

- **Hub-and-Spoke Network**: Centralized routing for multiple VPCs
- **Multi-Account Connectivity**: Share Transit Gateway across AWS accounts
- **Hybrid Cloud**: Connect VPCs and on-premises networks
- **Network Segmentation**: Isolated routing domains with separate route tables
- **Transit Routing**: Route traffic between VPCs without peering
- **Global Network**: Connect regions with Transit Gateway peering

## Architecture Patterns

### Simple Hub-and-Spoke

```
         ┌─────────┐
         │ Transit │
         │ Gateway │
         └────┬────┘
      ┌───────┼───────┐
      │       │       │
   ┌──▼──┐ ┌──▼──┐ ┌──▼──┐
   │VPC-A│ │VPC-B│ │VPC-C│
   └─────┘ └─────┘ └─────┘
```

### Segmented Network

```
   ┌──────────────────────┐
   │   Transit Gateway    │
   │  ┌────────────────┐  │
   │  │  Route Table   │  │
   │  │   Production   │  │
   │  └────────────────┘  │
   │  ┌────────────────┐  │
   │  │  Route Table   │  │
   │  │  Development   │  │
   │  └────────────────┘  │
   └──────────────────────┘
         │        │
    ┌────▼───┐ ┌─▼────┐
    │ Prod   │ │ Dev  │
    │ VPCs   │ │ VPCs │
    └────────┘ └──────┘
```

## Usage

### Basic Transit Gateway with VPC Attachments

```hcl
module "transit_gateway" {
  source = "./transit_gateway"

  name        = "main-tgw"
  description = "Main Transit Gateway for production"
  
  amazon_side_asn = 64512
  
  vpc_attachments = {
    vpc1 = {
      vpc_id     = module.vpc_app.vpc_id
      subnet_ids = module.vpc_app.private_subnet_ids
    }
    vpc2 = {
      vpc_id     = module.vpc_db.vpc_id
      subnet_ids = module.vpc_db.private_subnet_ids
    }
    vpc3 = {
      vpc_id     = module.vpc_shared.vpc_id
      subnet_ids = module.vpc_shared.private_subnet_ids
    }
  }
  
  # Add routes in VPC route tables pointing to TGW
  vpc_route_table_routes = {
    vpc1_to_others = {
      route_table_id         = module.vpc_app.private_route_table_ids[0]
      destination_cidr_block = "10.0.0.0/8"
    }
    vpc2_to_others = {
      route_table_id         = module.vpc_db.private_route_table_ids[0]
      destination_cidr_block = "10.0.0.0/8"
    }
  }
  
  enable_monitoring = true
  alarm_actions     = [aws_sns_topic.alerts.arn]
  
  tags = {
    Environment = "production"
  }
}
```

### Transit Gateway with Custom Route Tables

```hcl
module "transit_gateway_segmented" {
  source = "./transit_gateway"

  name = "segmented-tgw"
  
  # Disable default route table
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  
  vpc_attachments = {
    prod1 = {
      vpc_id                                          = module.vpc_prod1.vpc_id
      subnet_ids                                      = module.vpc_prod1.private_subnet_ids
      transit_gateway_default_route_table_association = false
      transit_gateway_default_route_table_propagation = false
    }
    prod2 = {
      vpc_id                                          = module.vpc_prod2.vpc_id
      subnet_ids                                      = module.vpc_prod2.private_subnet_ids
      transit_gateway_default_route_table_association = false
      transit_gateway_default_route_table_propagation = false
    }
    dev1 = {
      vpc_id                                          = module.vpc_dev1.vpc_id
      subnet_ids                                      = module.vpc_dev1.private_subnet_ids
      transit_gateway_default_route_table_association = false
      transit_gateway_default_route_table_propagation = false
    }
  }
  
  # Create custom route tables
  transit_gateway_route_tables = {
    production = {}
    development = {}
    shared = {}
  }
  
  # Associate VPCs with route tables
  transit_gateway_route_table_associations = {
    prod1_association = {
      vpc_attachment_id              = "prod1"
      transit_gateway_route_table_id = "production"
    }
    prod2_association = {
      vpc_attachment_id              = "prod2"
      transit_gateway_route_table_id = "production"
    }
    dev1_association = {
      vpc_attachment_id              = "dev1"
      transit_gateway_route_table_id = "development"
    }
  }
  
  # Configure route propagations
  transit_gateway_route_table_propagations = {
    prod1_to_prod_rt = {
      vpc_attachment_id              = "prod1"
      transit_gateway_route_table_id = "production"
    }
    prod2_to_prod_rt = {
      vpc_attachment_id              = "prod2"
      transit_gateway_route_table_id = "production"
    }
    dev1_to_dev_rt = {
      vpc_attachment_id              = "dev1"
      transit_gateway_route_table_id = "development"
    }
  }
  
  tags = {
    Segmentation = "enabled"
  }
}
```

### Cross-Account Transit Gateway

```hcl
# In the shared services account
module "transit_gateway_shared" {
  source = "./transit_gateway"

  name = "shared-tgw"
  
  vpc_attachments = {
    shared_services = {
      vpc_id     = module.vpc_shared.vpc_id
      subnet_ids = module.vpc_shared.private_subnet_ids
    }
  }
  
  # Enable resource sharing
  enable_resource_sharing = true
  ram_principals = [
    "123456789012",  # Production account
    "210987654321",  # Development account
  ]
  
  auto_accept_shared_attachments = "enable"
  
  tags = {
    Purpose = "cross-account-networking"
  }
}

# In other accounts, create VPC attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "app_vpc" {
  transit_gateway_id = "tgw-xxxxx"  # Shared TGW ID
  vpc_id             = module.vpc_app.vpc_id
  subnet_ids         = module.vpc_app.private_subnet_ids
}
```

### Cross-Region Transit Gateway with Peering

```hcl
# In us-east-1
module "tgw_us_east" {
  source = "./transit_gateway"

  name = "tgw-us-east-1"
  
  vpc_attachments = {
    app = {
      vpc_id     = module.vpc_us_east.vpc_id
      subnet_ids = module.vpc_us_east.private_subnet_ids
    }
  }
  
  # Create peering to us-west-2
  transit_gateway_peering_attachments = {
    to_us_west = {
      peer_transit_gateway_id = module.tgw_us_west.transit_gateway_id
      peer_region             = "us-west-2"
    }
  }
  
  tags = {
    Region = "us-east-1"
  }
}

# In us-west-2
module "tgw_us_west" {
  source = "./transit_gateway"
  
  providers = {
    aws = aws.us_west_2
  }

  name = "tgw-us-west-2"
  
  vpc_attachments = {
    app = {
      vpc_id     = module.vpc_us_west.vpc_id
      subnet_ids = module.vpc_us_west.private_subnet_ids
    }
  }
  
  # Accept peering from us-east-1
  transit_gateway_peering_accepters = {
    from_us_east = {
      transit_gateway_attachment_id = "tgw-attach-xxxxx"  # From us-east-1
    }
  }
  
  tags = {
    Region = "us-west-2"
  }
}
```

### With VPN and Flow Logs

```hcl
module "transit_gateway_vpn" {
  source = "./transit_gateway"

  name = "tgw-with-vpn"
  
  vpn_ecmp_support = "enable"  # Load balance across multiple VPN tunnels
  
  vpc_attachments = {
    vpc1 = {
      vpc_id     = module.vpc.vpc_id
      subnet_ids = module.vpc.private_subnet_ids
    }
  }
  
  enable_flow_logs          = true
  flow_logs_retention_days  = 90
  flow_logs_traffic_type    = "ALL"
  
  tags = {
    VPN = "enabled"
  }
}

# Attach VPN to Transit Gateway
module "vpn" {
  source = "./vpn"
  
  create_site_to_site_vpn     = true
  use_transit_gateway         = true
  transit_gateway_id          = module.transit_gateway_vpn.transit_gateway_id
  customer_gateway_ip_address = "203.0.113.1"
  
  # ECMP will distribute traffic across tunnels
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Transit Gateway name | string | - | yes |
| description | TGW description | string | "Transit Gateway for VPC connectivity" | no |
| amazon_side_asn | BGP ASN for TGW | number | 64512 | no |
| vpc_attachments | Map of VPC attachments | map(object) | {} | no |
| transit_gateway_route_tables | Custom route tables | map(object) | {} | no |
| enable_resource_sharing | Enable RAM sharing | bool | false | no |
| ram_principals | AWS principals to share with | list(string) | [] | no |
| enable_flow_logs | Enable flow logs | bool | false | no |
| enable_monitoring | Enable monitoring | bool | true | no |
| tags | Tags to apply | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| transit_gateway_id | Transit Gateway ID |
| transit_gateway_arn | Transit Gateway ARN |
| vpc_attachment_ids | Map of VPC attachment IDs |
| transit_gateway_route_table_ids | Map of route table IDs |
| ram_resource_share_arn | RAM share ARN |

## Important Considerations

### Routing

- **Default Behavior**: By default, all attachments can route to each other
- **Isolation**: Disable default route tables and create custom ones for segmentation
- **Static Routes**: Use for specific routing requirements
- **Propagation**: Enable for automatic route updates

### Pricing

- Transit Gateway charges:
  - Per hour per attachment
  - Per GB data processed
- Cross-region peering: Additional data transfer costs
- Plan capacity for expected traffic

### Limits

- Default: 5,000 attachments per Transit Gateway
- 10,000 routes per route table
- 50 peering attachments per Transit Gateway
- Request limit increases if needed

### Best Practices

1. **Use One TGW per Region**: Centralized routing within region
2. **Segment Networks**: Use separate route tables for prod/dev/test
3. **Enable Monitoring**: Track usage and performance
4. **Plan CIDR Blocks**: Avoid overlaps across VPCs
5. **Use RAM for Multi-Account**: Share TGW instead of peering
6. **Enable Flow Logs**: For troubleshooting and security
7. **Tag Consistently**: For cost allocation and management
8. **Implement ECMP**: For VPN redundancy and load balancing
9. **Document Routing**: Maintain route table documentation
10. **Test Failover**: Verify connectivity during outages

## Routing Examples

### Allow All Communication (Default)

```hcl
# All VPCs can communicate through default route table
default_route_table_association = "enable"
default_route_table_propagation = "enable"
```

### Isolated Production and Development

```hcl
# Production VPCs can only talk to each other
# Development VPCs can only talk to each other
# Shared services can talk to both

# Create 3 route tables: prod, dev, shared
# Associate prod VPCs with prod route table
# Associate dev VPCs with dev route table
# Propagate shared services to both prod and dev tables
```

### Hub-and-Spoke with Shared Services

```hcl
# Spoke VPCs cannot communicate directly
# All traffic goes through shared services VPC
# Shared services VPC has inspection/filtering appliances

# Use appliance_mode_support for symmetric routing
```

## Troubleshooting

### Connectivity Issues
- Check route table associations and propagations
- Verify security groups and NACLs
- Review VPC route tables have routes to TGW
- Ensure no CIDR overlap
- Check attachment state (available)

### Performance Issues
- Review CloudWatch metrics
- Check for bandwidth limits
- Consider multiple attachments for higher bandwidth
- Enable VPN ECMP for better distribution

### Cross-Account Issues
- Verify RAM share acceptance
- Check IAM permissions
- Ensure TGW is shared to correct principals
- Verify attachment auto-accept setting

## License

MIT
