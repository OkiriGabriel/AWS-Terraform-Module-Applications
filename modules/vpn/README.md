# VPN Module

This module creates VPN connections including Site-to-Site VPN for connecting on-premises networks and Client VPN for remote user access.

## Features

### Site-to-Site VPN
- IPSec VPN tunnels with redundancy (2 tunnels)
- BGP or static routing
- Integration with Virtual Private Gateway or Transit Gateway
- Customizable encryption and authentication parameters
- CloudWatch monitoring and alarms

### Client VPN
- Remote user VPN access
- Multiple authentication methods (certificates, Active Directory, SAML)
- Split tunnel support
- Connection logging
- Network associations with VPC subnets
- Granular authorization rules

## Use Cases

### Site-to-Site VPN
- Connect on-premises data center to AWS
- Hybrid cloud architectures
- Disaster recovery setup
- Multi-cloud connectivity

### Client VPN
- Remote employee access to AWS resources
- Secure access for contractors
- Development environment access
- Administrative access to private resources

## Usage

### Site-to-Site VPN with Virtual Private Gateway

```hcl
module "site_to_site_vpn" {
  source = "./modules/vpn"

  name_prefix = "company-hq"
  vpc_id      = module.vpc.vpc_id
  
  create_site_to_site_vpn        = true
  customer_gateway_ip_address    = "203.0.113.1"  # Your public IP
  customer_gateway_bgp_asn       = 65000
  amazon_side_asn                = 64512
  
  route_table_ids = module.vpc.private_route_table_ids
  
  # Optional: Custom tunnel configuration
  tunnel1_preshared_key = var.tunnel1_psk  # Use Secrets Manager
  tunnel2_preshared_key = var.tunnel2_psk
  
  enable_monitoring = true
  alarm_actions     = [aws_sns_topic.alerts.arn]
  
  tags = {
    Environment = "production"
    Purpose     = "on-premises-connectivity"
  }
}
```

### Site-to-Site VPN with Transit Gateway

```hcl
module "site_to_site_vpn_tgw" {
  source = "./modules/vpn"

  name_prefix = "branch-office"
  vpc_id      = module.vpc.vpc_id
  
  create_site_to_site_vpn     = true
  use_transit_gateway         = true
  transit_gateway_id          = module.transit_gateway.transit_gateway_id
  customer_gateway_ip_address = "198.51.100.1"
  
  # Use BGP for dynamic routing
  static_routes_only = false
  
  tags = {
    Office = "branch-ny"
  }
}
```

### Site-to-Site VPN with Static Routes

```hcl
module "vpn_static" {
  source = "./modules/vpn"

  name_prefix = "datacenter"
  vpc_id      = module.vpc.vpc_id
  
  create_site_to_site_vpn     = true
  customer_gateway_ip_address = "192.0.2.1"
  
  static_routes_only = true
  static_routes      = [
    "10.0.0.0/8",
    "172.16.0.0/12"
  ]
  
  route_table_ids = module.vpc.private_route_table_ids
  
  tags = {
    Location = "primary-datacenter"
  }
}
```

### Client VPN with Certificate Authentication

```hcl
module "client_vpn" {
  source = "./modules/vpn"

  name_prefix = "employee-vpn"
  vpc_id      = module.vpc.vpc_id
  
  create_client_vpn          = true
  server_certificate_arn     = aws_acm_certificate.server.arn
  client_root_certificate_arn = aws_acm_certificate.client_root.arn
  
  client_cidr_block = "172.16.0.0/22"
  split_tunnel      = true
  
  authentication_type = "certificate-authentication"
  
  client_vpn_subnet_ids = module.vpc.private_subnet_ids
  client_vpn_security_group_ids = [module.client_vpn_sg.security_group_id]
  
  # Allow access to VPC CIDR
  client_vpn_authorization_rules = [
    {
      target_network_cidr  = "10.0.0.0/16"
      authorize_all_groups = true
      description          = "Allow access to VPC"
    }
  ]
  
  # Route traffic to VPC
  client_vpn_routes = [
    {
      destination_cidr_block = "10.0.0.0/16"
      target_vpc_subnet_id   = module.vpc.private_subnet_ids[0]
      description            = "Route to VPC"
    }
  ]
  
  enable_connection_logging = true
  log_retention_days        = 90
  
  tags = {
    Purpose = "remote-access"
  }
}
```

### Client VPN with Active Directory

```hcl
module "client_vpn_ad" {
  source = "./modules/vpn"

  name_prefix = "corporate-vpn"
  vpc_id      = module.vpc.vpc_id
  
  create_client_vpn       = true
  server_certificate_arn  = aws_acm_certificate.server.arn
  
  client_cidr_block = "172.16.0.0/22"
  split_tunnel      = false  # Full tunnel for corporate policy
  
  authentication_type = "directory-service-authentication"
  active_directory_id = aws_directory_service_directory.corp.id
  
  client_vpn_subnet_ids = module.vpc.private_subnet_ids
  
  # Group-based access control
  client_vpn_authorization_rules = [
    {
      target_network_cidr  = "10.0.0.0/16"
      authorize_all_groups = false
      access_group_id      = "S-1-5-21-123456789-1234567890-1234567890-1001"  # AD group SID
      description          = "Developers group"
    },
    {
      target_network_cidr  = "10.0.100.0/24"
      authorize_all_groups = false
      access_group_id      = "S-1-5-21-123456789-1234567890-1234567890-1002"
      description          = "Admins group"
    }
  ]
  
  dns_servers = ["10.0.0.2"]  # AD DNS servers
  
  tags = {
    AuthMethod = "active-directory"
  }
}
```

## Inputs

### Common Variables
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name_prefix | Prefix for resource names | string | "vpn" | no |
| vpc_id | VPC ID | string | - | yes |
| enable_monitoring | Enable monitoring | bool | true | no |
| tags | Tags to apply | map(string) | {} | no |

### Site-to-Site VPN
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| create_site_to_site_vpn | Create Site-to-Site VPN | bool | false | no |
| customer_gateway_ip_address | Customer gateway IP | string | null | yes* |
| customer_gateway_bgp_asn | BGP ASN | number | 65000 | no |
| use_transit_gateway | Use Transit Gateway | bool | false | no |
| static_routes_only | Use static routing | bool | false | no |
| route_table_ids | Route table IDs | list(string) | [] | no |

### Client VPN
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| create_client_vpn | Create Client VPN | bool | false | no |
| server_certificate_arn | Server certificate ARN | string | null | yes* |
| client_cidr_block | Client CIDR block | string | "172.16.0.0/22" | no |
| split_tunnel | Enable split tunnel | bool | true | no |
| authentication_type | Auth type | string | "certificate-authentication" | no |
| client_vpn_subnet_ids | Subnet IDs | list(string) | [] | yes* |

## Outputs

### Site-to-Site VPN
| Name | Description |
|------|-------------|
| vpn_connection_id | VPN connection ID |
| vpn_connection_tunnel1_address | Tunnel 1 public IP |
| vpn_connection_tunnel2_address | Tunnel 2 public IP |
| customer_gateway_id | Customer gateway ID |

### Client VPN
| Name | Description |
|------|-------------|
| client_vpn_endpoint_id | Client VPN endpoint ID |
| client_vpn_endpoint_dns_name | Client VPN DNS name |
| client_vpn_network_associations | Network association IDs |

## Prerequisites

### Site-to-Site VPN
1. Public IP address for your customer gateway
2. Compatible VPN device (Cisco, Juniper, pfSense, etc.)
3. BGP ASN (if using dynamic routing)

### Client VPN
1. **Certificate Authentication**:
   - Server certificate in ACM
   - Client root certificate in ACM
   - Generate and distribute client certificates

2. **Active Directory Authentication**:
   - AWS Directory Service directory
   - AD security groups for authorization

3. **SAML Authentication**:
   - SAML 2.0 identity provider
   - IAM SAML provider

## Generating Certificates for Client VPN

```bash
# Generate CA
easy-rsa init-pki
easy-rsa build-ca nopass

# Generate server certificate
easy-rsa build-server-full server nopass

# Generate client certificate
easy-rsa build-client-full client1.domain.tld nopass

# Upload to ACM
aws acm import-certificate \
  --certificate fileb://server.crt \
  --private-key fileb://server.key \
  --certificate-chain fileb://ca.crt

aws acm import-certificate \
  --certificate fileb://client1.domain.tld.crt \
  --private-key fileb://client1.domain.tld.key \
  --certificate-chain fileb://ca.crt
```

## Connecting to Client VPN

1. Download client configuration:
```bash
aws ec2 export-client-vpn-client-configuration \
  --client-vpn-endpoint-id cvpn-endpoint-xxxxx \
  --output text > client-config.ovpn
```

2. Add certificate and key to config file

3. Connect using OpenVPN client

## Monitoring and Troubleshooting

### Site-to-Site VPN
- Check tunnel status in VPC Console
- Review CloudWatch metrics: `TunnelState`, `TunnelDataIn`, `TunnelDataOut`
- Verify customer gateway configuration
- Check security group and NACL rules
- Verify BGP peering (if using dynamic routing)

### Client VPN
- Monitor connection logs in CloudWatch
- Check authorization rules
- Verify DNS resolution
- Review security group rules
- Test connectivity from client

## Best Practices

1. **Use Strong Encryption**: Enable AES-256-GCM and SHA2-512
2. **Monitor Tunnel Health**: Set up CloudWatch alarms
3. **Redundancy**: Both tunnels should be configured on customer side
4. **Rotate Keys**: Regularly rotate pre-shared keys
5. **Split Tunnel**: Use for Client VPN to reduce bandwidth
6. **Logging**: Enable connection logging for audit and troubleshooting
7. **Least Privilege**: Use specific authorization rules, not authorize_all
8. **Certificate Management**: Automate certificate rotation

## Cost Considerations

- **Site-to-Site VPN**: Charged per VPN connection hour + data transfer
- **Client VPN**: Charged per endpoint hour + per connection hour + data transfer
- **Data Transfer**: Additional charges for data transfer out of AWS

## License

MIT
