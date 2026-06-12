# Gabriel AWS Infrastructure Boilerplate

[![Terraform](https://img.shields.io/badge/Terraform-v1.0+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Compatible-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

A comprehensive, production-ready Terraform boilerplate for deploying complete AWS infrastructure. This module provides a robust foundation for building scalable, secure, and highly available applications on AWS.

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Module Structure](#module-structure)
- [Available Modules](#available-modules)
- [Usage Examples](#usage-examples)
- [Configuration](#configuration)
- [Security](#security)
- [Monitoring & Observability](#monitoring--observability)
- [Contributing](#contributing)
- [License](#license)

## Features

### Core Infrastructure
- **VPC & Networking**: Multi-AZ VPC with public/private subnets, NAT gateways, VPC peering, Transit Gateway
- **Compute**: ECS (EC2 & Fargate), EKS (Kubernetes), EC2 instances
- **Database**: RDS (MySQL/PostgreSQL), ElastiCache (Redis/Memcached), DynamoDB
- **Storage**: S3 buckets with lifecycle policies, EFS file systems
- **Load Balancing**: Application Load Balancers with SSL/TLS termination
- **CDN**: CloudFront distributions for static content delivery
- **Container Registry**: ECR repositories with lifecycle policies

### Security & Compliance
- **AWS GuardDuty**: Threat detection and continuous security monitoring
- **AWS Inspector**: Automated vulnerability assessment
- **Secrets Management**: AWS Secrets Manager integration
- **SSL/TLS**: ACM certificates with automatic renewal
- **Security Groups**: Layered security with principle of least privilege
- **VPN**: Site-to-Site VPN and Client VPN for secure access
- **Network Segmentation**: Transit Gateway for hub-and-spoke architecture

### Monitoring & Observability
- **CloudWatch**: Metrics, logs, and alarms
- **Container Insights**: Enhanced container monitoring
- **VPC Flow Logs**: Network traffic analysis
- **Custom Dashboards**: Pre-configured monitoring dashboards
- **Alerting**: SNS-based notification system
- **X-Ray**: Distributed tracing (optional)

### DevOps & Automation
- **CI/CD Ready**: ECR integration for container workflows
- **Multi-Environment**: Separate dev/staging/prod configurations
- **Backup & DR**: Automated backups with point-in-time recovery
- **Auto Scaling**: Dynamic resource scaling based on demand
- **Infrastructure as Code**: 100% Terraform managed

## Architecture

This boilerplate implements a production-grade AWS architecture with the following key components:

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                             │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              Transit Gateway (Hub)                  │    │
│  │  Connects: VPCs, VPN, On-Premises Networks         │    │
│  └──────────────┬─────────────────────────────────────┘    │
│                 │                                            │
│  ┌──────────────▼──────────────────────────────────────┐   │
│  │  VPC (Multi-AZ)                                      │   │
│  │  ┌─────────────┐        ┌─────────────┐            │   │
│  │  │ Public      │        │ Private     │            │   │
│  │  │ Subnet AZ-A │        │ Subnet AZ-A │            │   │
│  │  │ - ALB       │        │ - ECS/EKS   │            │   │
│  │  │ - NAT GW    │        │ - RDS       │            │   │
│  │  └─────────────┘        │ - ElastiCache│           │   │
│  │  ┌─────────────┐        └─────────────┘            │   │
│  │  │ Public      │        ┌─────────────┐            │   │
│  │  │ Subnet AZ-B │        │ Private     │            │   │
│  │  │ - ALB       │        │ Subnet AZ-B │            │   │
│  │  │ - NAT GW    │        │ - ECS/EKS   │            │   │
│  │  └─────────────┘        │ - RDS (HA)  │            │   │
│  │                         └─────────────┘            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Security & Monitoring                               │   │
│  │  - GuardDuty (Threat Detection)                     │   │
│  │  - Inspector (Vulnerability Scanning)               │   │
│  │  - CloudWatch (Logging & Metrics)                   │   │
│  │  - VPC Flow Logs                                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Global Services                                     │   │
│  │  - CloudFront CDN                                   │   │
│  │  - Route53 DNS                                      │   │
│  │  - ACM Certificates                                 │   │
│  │  - S3 (Static Assets, Backups)                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- **Terraform**: >= 1.0.0
- **AWS CLI**: >= 2.0
- **AWS Account**: With appropriate IAM permissions
- **Git**: For version control

### Required IAM Permissions

Your AWS user/role needs permissions for:
- VPC, EC2, ECS, EKS
- RDS, ElastiCache, DynamoDB
- S3, CloudFront, Route53
- IAM (for role creation)
- CloudWatch, GuardDuty, Inspector
- Secrets Manager, ACM
- Transit Gateway, VPN

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/gabriel-aws-infrastructure.git
   cd gabriel-aws-infrastructure
   ```

2. **Configure AWS credentials**
   ```bash
   aws configure
   # Or export AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
   ```

3. **Update Terraform Cloud settings** (or use local backend)
   Edit `provider.tf` to configure your backend:
   ```hcl
   terraform {
     cloud {
       organization = "your-org"
       workspaces {
         name = "your-workspace"
       }
     }
   }
   ```

4. **Customize your environment**
   Edit `vars_enviro_dev.tf` or `vars_enviro_prod.tf` to match your needs:
   - VPC CIDR ranges
   - Instance types
   - Database configurations
   - S3 bucket names
   - Domain names

5. **Initialize and deploy**
   ```bash
   terraform init
   terraform workspace select default  # or create new workspace
   terraform plan
   terraform apply
   ```

## Module Structure

```
.
├── modules/                    # Reusable Terraform modules
│   ├── vpc/                   # VPC with subnets, NAT, IGW
│   ├── eks/                   # Amazon EKS cluster
│   ├── ecs_service/           # ECS service definition
│   ├── alb/                   # Application Load Balancer
│   ├── rds/                   # RDS database instances
│   ├── elasticache/           # ElastiCache clusters
│   ├── s3/                    # S3 buckets with policies
│   ├── security_groups/       # Security group definitions
│   ├── monitoring/            # CloudWatch dashboards & alarms
│   ├── secrets_manager/       # Secrets management
│   ├── dynamodb/             # DynamoDB tables
│   ├── cloudfront_static/    # CloudFront distributions
│   ├── guardduty/            # GuardDuty threat detection
│   ├── inspector/            # Inspector vulnerability scanning
│   ├── vpc_peering/          # VPC peering connections
│   ├── vpn/                  # VPN connections
│   └── transit_gateway/      # Transit Gateway setup
├── environments/              # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
├── *.tf                       # Root module configurations
├── vars_enviro_dev.tf        # Development variables
├── vars_enviro_prod.tf       # Production variables
└── README.md                  # This file
```

## Available Modules

### Networking
- **VPC** - Multi-AZ VPC with public/private subnets
- **VPC Peering** - Connect multiple VPCs
- **Transit Gateway** - Hub-and-spoke network architecture
- **VPN** - Site-to-Site and Client VPN connections

### Compute
- **ECS** - Container orchestration with EC2 and Fargate
- **EKS** - Managed Kubernetes clusters
- **EC2** - Virtual machine instances

### Database & Caching
- **RDS** - Relational databases (MySQL, PostgreSQL)
- **ElastiCache** - In-memory caching (Redis, Memcached)
- **DynamoDB** - NoSQL database

### Storage & CDN
- **S3** - Object storage with lifecycle policies
- **EFS** - Elastic file system
- **CloudFront** - Content delivery network

### Security
- **GuardDuty** - Intelligent threat detection
- **Inspector** - Automated security assessment
- **Secrets Manager** - Secure credential storage
- **ACM** - SSL/TLS certificate management

### Monitoring
- **CloudWatch** - Metrics, logs, and alarms
- **VPC Flow Logs** - Network traffic monitoring
- **Container Insights** - ECS/EKS monitoring

## Usage Examples

All examples are available in `examples.tf` - just uncomment the module you want to use!

### EKS Cluster (Kubernetes)

```hcl
module "eks" {
  source = "./modules/eks"

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
```

### GuardDuty (Threat Detection)

```hcl
module "guardduty" {
  source = "./modules/guardduty"

  name_prefix = "${local.project_name}-guardduty"
  
  enable                       = true
  enable_s3_protection         = true
  enable_kubernetes_protection = true
  enable_malware_protection    = true
  
  enable_notifications   = true
  notification_emails    = ["security@example.com"]
  minimum_severity_level = 4.0
  
  enable_findings_export = true
  enable_cloudwatch_logs = true
  
  tags = local.tags
}
```

### Inspector (Vulnerability Scanning)

```hcl
module "inspector" {
  source = "./modules/inspector"

  name_prefix = "${local.project_name}-inspector"
  
  resource_types = ["EC2", "ECR", "LAMBDA"]
  
  enable_notifications = true
  notification_emails  = ["security@example.com"]
  severity_filter      = ["CRITICAL", "HIGH"]
  
  enable_cloudwatch_logs = true
  enable_report_export   = true
  
  tags = local.tags
}
```

### VPC Peering

```hcl
module "vpc_peering" {
  source = "./modules/vpc_peering"

  requester_vpc_id     = module.vpc.vpc_id
  accepter_vpc_id      = "vpc-xxxxxxxxx"
  requester_cidr_block = local.current_env.vpc.cidr
  accepter_cidr_block  = "10.1.0.0/16"
  
  requester_route_table_ids = module.vpc.private_route_table_ids
  accepter_route_table_ids  = ["rtb-xxxxxxxxx"]
  
  auto_accept  = true
  peering_name = "${local.project_name}-peering"
  
  tags = local.tags
}
```

### Site-to-Site VPN (Connect to On-Premises)

```hcl
module "site_to_site_vpn" {
  source = "./modules/vpn"

  name_prefix = "${local.project_name}-vpn"
  vpc_id      = module.vpc.vpc_id
  
  create_site_to_site_vpn     = true
  customer_gateway_ip_address = "YOUR.PUBLIC.IP.ADDRESS"
  customer_gateway_bgp_asn    = 65000
  
  route_table_ids = module.vpc.private_route_table_ids
  
  enable_monitoring = true
  
  tags = local.tags
}
```

### Client VPN (Remote User Access)

```hcl
module "client_vpn" {
  source = "./modules/vpn"

  name_prefix = "${local.project_name}-client-vpn"
  vpc_id      = module.vpc.vpc_id
  
  create_client_vpn = true
  
  server_certificate_arn      = "arn:aws:acm:us-east-1:ACCOUNT:certificate/SERVER-CERT-ID"
  client_root_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CLIENT-CERT-ID"
  
  client_cidr_block   = "172.16.0.0/22"
  split_tunnel        = true
  authentication_type = "certificate-authentication"
  
  client_vpn_subnet_ids         = module.vpc.private_subnet_ids
  client_vpn_security_group_ids = [module.security_groups.ecs_instances_security_group_id]
  
  client_vpn_authorization_rules = [
    {
      target_network_cidr  = local.current_env.vpc.cidr
      authorize_all_groups = true
      description          = "Allow access to VPC"
    }
  ]
  
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
```

### Transit Gateway (Hub-and-Spoke Network)

```hcl
module "transit_gateway" {
  source = "./modules/transit_gateway"

  name        = "${local.project_name}-tgw"
  description = "Transit Gateway for connecting multiple VPCs"
  
  amazon_side_asn = 64512
  
  vpc_attachments = {
    main = {
      vpc_id     = module.vpc.vpc_id
      subnet_ids = module.vpc.private_subnet_ids
    }
  }
  
  vpc_route_table_routes = {
    main_to_tgw = {
      route_table_id         = module.vpc.private_route_table_ids[0]
      destination_cidr_block = "10.0.0.0/8"
    }
  }
  
  enable_monitoring = true
  enable_flow_logs  = true
  
  tags = local.tags
}
```

### Complete Security Suite

```hcl
# Enable all security features
module "guardduty" {
  source          = "./modules/guardduty"
  name_prefix     = "${local.project_name}-guardduty"
  enable_notifications = true
  notification_emails  = ["security@example.com"]
  tags = local.tags
}

module "inspector" {
  source          = "./modules/inspector"
  name_prefix     = "${local.project_name}-inspector"
  resource_types  = ["EC2", "ECR", "LAMBDA"]
  enable_notifications = true
  notification_emails  = ["security@example.com"]
  tags = local.tags
}
```

## Configuration

### Environment Variables

The module uses workspace-based environment selection. Configure your environments in:
- `vars_enviro_dev.tf` - Development environment
- `vars_enviro_prod.tf` - Production environment

### Key Configuration Options

```hcl
locals {
  dev = {
    environment  = "dev"
    project_name = "my-project"
    
    vpc = {
      cidr            = "10.0.0.0/16"
      public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
      private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]
      azs             = ["us-east-1a", "us-east-1b"]
    }
    
    rds = {
      instance_class = "db.t3.micro"
      multi_az       = false
      engine         = "mysql"
      engine_version = "8.0"
    }
    
    eks = {
      cluster_version = "1.28"
      node_groups = {
        general = {
          instance_types = ["t3.medium"]
          desired_size   = 2
        }
      }
    }
  }
}
```

## Security

### Security Features

- **Network Isolation**: Private subnets for application tier
- **Security Groups**: Layered security with least privilege
- **Encryption**: At-rest and in-transit encryption
- **Secret Management**: AWS Secrets Manager for credentials
- **Threat Detection**: GuardDuty for anomaly detection
- **Vulnerability Scanning**: Inspector for OS/application scanning
- **VPN Access**: Secure remote access via VPN
- **Network Monitoring**: VPC Flow Logs for traffic analysis

### Best Practices

1. **Never commit secrets**: Use Secrets Manager or environment variables
2. **Enable MFA**: For AWS account access
3. **Use IAM roles**: Instead of access keys where possible
4. **Regular updates**: Keep Terraform and providers up to date
5. **Review security groups**: Regularly audit and minimize access
6. **Enable GuardDuty**: Continuous threat monitoring
7. **Implement backups**: Regular automated backups with testing

## Monitoring & Observability

### CloudWatch Dashboards

The module creates pre-configured dashboards for:
- ECS/EKS cluster metrics
- RDS database performance
- ALB request metrics
- ElastiCache performance
- Lambda invocations (if used)

### Alarms & Notifications

Default alarms configured for:
- High CPU utilization
- Memory pressure
- Database connections
- ALB 5xx errors
- ECS service failures

Configure SNS topics in your environment files for notifications.

## Contributing

We welcome contributions! This project is designed to be a community-driven boilerplate.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make your changes**
   - Add new modules
   - Improve existing modules
   - Fix bugs
   - Update documentation
4. **Test your changes**
   ```bash
   terraform fmt
   terraform validate
   terraform plan
   ```
5. **Commit your changes**
   ```bash
   git commit -m 'Add some amazing feature'
   ```
6. **Push to the branch**
   ```bash
   git push origin feature/amazing-feature
   ```
7. **Open a Pull Request**

### Contribution Guidelines

- Follow Terraform best practices
- Include documentation for new modules
- Add examples for new features
- Ensure backward compatibility
- Write clear commit messages
- Update README.md if needed

### Module Development

When creating new modules:
1. Follow the existing module structure
2. Include `variables.tf`, `main.tf`, and `outputs.tf`
3. Add a README.md in the module directory
4. Include examples in the module
5. Add appropriate tags to resources
6. Implement proper error handling

### Code Style

- Use consistent naming conventions
- Follow Terraform style guide
- Run `terraform fmt` before committing
- Use meaningful variable names
- Comment complex logic

## Roadmap

- [ ] Add AWS App Mesh support
- [ ] Implement AWS Backup module
- [ ] Add AWS WAF configuration
- [ ] Create Step Functions module
- [ ] Add AWS Lake Formation support
- [ ] Implement multi-region support
- [ ] Add cost optimization recommendations
- [ ] Create Terraform testing framework

## Support & Community

- **Issues**: [GitHub Issues](https://github.com/yourusername/gabriel-aws-infrastructure/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/gabriel-aws-infrastructure/discussions)
- **Documentation**: [Wiki](https://github.com/yourusername/gabriel-aws-infrastructure/wiki)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- AWS for comprehensive cloud services
- HashiCorp for Terraform
- Open source community for inspiration and contributions

## Authors

Created with love by the open source community.

---

**Note**: This is a boilerplate/template project. Always review and customize the configuration for your specific use case, especially security settings and resource sizing.
