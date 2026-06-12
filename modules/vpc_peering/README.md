# VPC Peering Module

This module creates VPC peering connections between VPCs, enabling private connectivity across VPCs in the same or different regions/accounts.

## Features

- Same-account and cross-account VPC peering
- Same-region and cross-region VPC peering
- Automatic route table updates
- DNS resolution across peered VPCs
- Optional security group rule creation
- CloudWatch monitoring
- Support for VPC peering options

## Use Cases

- **Multi-tier Architecture**: Connect application tier VPCs with database tier VPCs
- **Hub-and-Spoke**: Connect spoke VPCs to a central hub VPC
- **Shared Services**: Access shared services (monitoring, logging) from multiple VPCs
- **Development Isolation**: Peer dev/staging VPCs while keeping them separate
- **Cross-Region DR**: Connect primary and disaster recovery VPCs

## Usage

### Basic Same-Region Peering

```hcl
module "vpc_peering" {
  source = "./modules/vpc_peering"

  requester_vpc_id    = "vpc-12345678"
  accepter_vpc_id     = "vpc-87654321"
  requester_cidr_block = "10.0.0.0/16"
  accepter_cidr_block  = "10.1.0.0/16"
  
  requester_route_table_ids = ["rtb-111111", "rtb-222222"]
  accepter_route_table_ids  = ["rtb-333333", "rtb-444444"]
  
  auto_accept   = true
  peering_name  = "app-to-database"
  
  tags = {
    Environment = "production"
  }
}
```

### Cross-Region Peering

```hcl
module "vpc_peering_cross_region" {
  source = "./modules/vpc_peering"

  requester_vpc_id    = "vpc-us-east-1"
  accepter_vpc_id     = "vpc-eu-west-1"
  requester_cidr_block = "10.0.0.0/16"
  accepter_cidr_block  = "10.2.0.0/16"
  
  peer_region = "eu-west-1"
  auto_accept = false  # Manual acceptance required for cross-region
  
  requester_route_table_ids = ["rtb-111111"]
  accepter_route_table_ids  = ["rtb-555555"]
  
  peering_name = "us-east-to-eu-west"
  
  tags = {
    Purpose = "disaster-recovery"
  }
}
```

### Cross-Account Peering

```hcl
module "vpc_peering_cross_account" {
  source = "./modules/vpc_peering"

  requester_vpc_id    = "vpc-account-a"
  accepter_vpc_id     = "vpc-account-b"
  requester_cidr_block = "10.0.0.0/16"
  accepter_cidr_block  = "10.3.0.0/16"
  
  peer_owner_id = "123456789012"  # Account ID of accepter
  auto_accept   = false           # Manual acceptance required
  
  requester_route_table_ids = ["rtb-111111"]
  
  peering_name = "prod-to-shared-services"
  
  tags = {
    Owner = "platform-team"
  }
}
```

### With Security Group Rules

```hcl
module "vpc_peering_with_sg" {
  source = "./modules/vpc_peering"

  requester_vpc_id    = module.vpc_app.vpc_id
  accepter_vpc_id     = module.vpc_db.vpc_id
  requester_cidr_block = "10.0.0.0/16"
  accepter_cidr_block  = "10.1.0.0/16"
  
  requester_route_table_ids = module.vpc_app.private_route_table_ids
  accepter_route_table_ids  = module.vpc_db.private_route_table_ids
  
  create_security_group_rules   = true
  requester_security_group_ids = [module.app_sg.security_group_id]
  accepter_security_group_ids  = [module.db_sg.security_group_id]
  
  peering_name = "app-db-peering"
}
```

### With Monitoring

```hcl
module "vpc_peering_monitored" {
  source = "./modules/vpc_peering"

  requester_vpc_id    = "vpc-12345678"
  accepter_vpc_id     = "vpc-87654321"
  requester_cidr_block = "10.0.0.0/16"
  accepter_cidr_block  = "10.1.0.0/16"
  
  requester_route_table_ids = ["rtb-111111"]
  accepter_route_table_ids  = ["rtb-222222"]
  
  enable_monitoring = true
  alarm_actions     = [aws_sns_topic.alerts.arn]
  
  peering_name = "critical-peering"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| requester_vpc_id | Requester VPC ID | string | - | yes |
| accepter_vpc_id | Accepter VPC ID | string | - | yes |
| requester_cidr_block | Requester VPC CIDR | string | - | yes |
| accepter_cidr_block | Accepter VPC CIDR | string | - | yes |
| peer_owner_id | Accepter AWS account ID | string | null | no |
| peer_region | Accepter VPC region | string | null | no |
| auto_accept | Auto-accept peering | bool | true | no |
| peering_name | Name for the peering connection | string | null | no |
| requester_route_table_ids | Requester route tables | list(string) | [] | no |
| accepter_route_table_ids | Accepter route tables | list(string) | [] | no |
| create_security_group_rules | Create SG rules | bool | false | no |
| enable_monitoring | Enable monitoring | bool | false | no |
| tags | Tags to apply | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| peering_connection_id | VPC peering connection ID |
| peering_connection_status | Peering connection status |
| requester_vpc_id | Requester VPC ID |
| accepter_vpc_id | Accepter VPC ID |
| peering_connection_arn | Peering connection ARN |

## Important Considerations

### CIDR Overlaps
- Peered VPCs cannot have overlapping CIDR blocks
- Plan your IP addressing carefully

### Transitive Peering
- VPC peering is NOT transitive
- If VPC A peers with B, and B peers with C, A cannot communicate with C directly
- Use Transit Gateway for transitive routing

### DNS Resolution
- Enable DNS resolution for hostname resolution across VPCs
- Requires `enableDnsHostnames` and `enableDnsSupport` on both VPCs

### Security Groups
- Security group rules cannot reference security groups in peered VPCs directly
- Use CIDR blocks instead

### Cross-Account Setup

For cross-account peering:

1. **Requester (Account A)**:
   ```bash
   terraform apply  # Creates peering request
   ```

2. **Accepter (Account B)**:
   - Accept the peering request in the AWS console or via CLI
   - Or use `aws_vpc_peering_connection_accepter` resource

### Cross-Region Setup

For cross-region peering:
- Data transfer costs apply for cross-region traffic
- Slightly higher latency
- Manual acceptance required

## Best Practices

1. **Use Descriptive Names**: Name peering connections clearly
2. **Document CIDR Blocks**: Keep track of all VPC CIDR blocks
3. **Limit Route Tables**: Only add routes to necessary route tables
4. **Security Groups**: Be selective with security group rules
5. **Monitor Peering**: Enable monitoring for critical connections
6. **Tag Resources**: Use consistent tagging for organization
7. **Plan for Scale**: Consider Transit Gateway for complex topologies

## Troubleshooting

### Peering Connection Stuck in "pending-acceptance"
- Check that `auto_accept = true` for same account/region
- Manually accept for cross-account/region
- Verify IAM permissions

### Routes Not Working
- Verify route table associations
- Check security group rules
- Ensure no CIDR overlap
- Verify NACLs allow traffic

### DNS Not Resolving
- Enable `allow_remote_vpc_dns_resolution` on both sides
- Ensure VPCs have DNS support enabled
- Check Route53 resolver settings

## License

MIT
