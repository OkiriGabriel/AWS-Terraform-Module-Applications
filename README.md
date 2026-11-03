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
- [Upgrade Notes](#upgrade-notes)
- [Monitoring & Observability](#monitoring--observability)
- [CI/CD](#cicd)
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
- **Security Baseline**: Multi-region CloudTrail (KMS, log file validation), CIS Benchmark alarms, IAM Access Analyzer, EBS encryption by default, Security Hub FSBP + CIS v3.0 standards
- **AWS GuardDuty**: Threat detection and continuous security monitoring (incl. RDS login monitoring in prod)
- **AWS Inspector**: Automated vulnerability assessment
- **AWS WAF**: Managed rule sets, SQLi protection, rate limiting and geo blocking on the ALB (prod)
- **Secrets Management**: RDS master password generated and rotated by RDS in Secrets Manager (never in Terraform state)
- **Keyless CI/CD**: GitHub Actions OIDC deploy role, branch-scoped and least-privilege
- **Hardened compute**: IMDSv2 enforced, encrypted gp3 root volumes, SSM Session Manager instead of SSH
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
- **CI/CD Ready**: ECR integration, OIDC deploy role, CI with fmt/validate/TFLint/Gitleaks/Checkov
- **Safe Deployments**: ECS deployment circuit breaker with automatic rollback, CPU + memory autoscaling
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
├── vpc/                       # VPC with subnets, NAT, IGW
├── eks/                       # Amazon EKS cluster
├── ecs_service/               # ECS service definition
├── alb/                       # Application Load Balancer
├── rds/                       # RDS database instances
├── elasticache/               # ElastiCache clusters
├── s3/                        # S3 buckets with policies
├── security_groups/           # Security group definitions
├── monitoring/                # CloudWatch dashboards & alarms
├── secrets_manager/           # Secrets management
├── dynamodb/                  # DynamoDB tables
├── cloudfront_static/         # CloudFront distributions
├── guardduty/                 # GuardDuty threat detection
├── inspector/                 # Inspector vulnerability scanning
├── vpc_peering/               # VPC peering connections
├── vpn/                       # VPN connections
├── transit_gateway/           # Transit Gateway setup
├── *.tf                       # Root infrastructure configurations
├── security_baseline.tf       # CloudTrail, CIS alarms, Access Analyzer, EBS encryption, Security Hub standards
├── security_enhancements.tf   # WAF, Security Hub, AWS Config, VPC Flow Logs
├── cicd_oidc.tf               # GitHub Actions OIDC deploy role (opt-in)
├── vars_enviro_dev.tf         # Development variables
├── vars_enviro_prod.tf        # Production variables
├── examples.tf                # Usage examples for all modules
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
- **Security Baseline** - CloudTrail, CIS Benchmark alarms, IAM Access Analyzer, Security Hub standards
- **WAF** - Managed rules, SQLi protection, rate limiting (prod ALB)

### Monitoring
- **CloudWatch** - Metrics, logs, and alarms
- **VPC Flow Logs** - Network traffic monitoring
- **Container Insights** - ECS/EKS monitoring

## Usage Examples

All examples are available in `examples.tf` - just uncomment the module you want to use!

### EKS Cluster (Kubernetes)

```hcl
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
```

### GuardDuty (Threat Detection)

```hcl
module "guardduty" {
  source = "./guardduty"

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
  source = "./inspector"

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
  source = "./vpc_peering"

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
  source = "./vpn"

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
  source = "./vpn"

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
  source = "./transit_gateway"

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

### Account Security Baseline

`security_baseline.tf` is on by default in every workspace. Tune it per environment with a
`security_features` block in `vars_enviro_*.tf` (any key you omit keeps its default from `locals.tf`):

```hcl
locals {
  prod = {
    # ...
    security_features = {
      enable_cloudtrail             = true   # multi-region trail, KMS-encrypted, log file validation
      cloudtrail_log_retention_days = 365    # CloudWatch Logs retention; S3 copy moves to Glacier after 90 days
      enable_cis_alarms             = true   # 13 CIS metric-filter alarms -> alerts SNS topic
      enable_access_analyzer        = true
      enable_ebs_default_encryption = true   # account/region singleton: enable in ONE workspace per account
      enable_security_hub_standards = true   # prod only: AWS FSBP + CIS v3.0.0
      alert_email                   = "secops@example.com"  # confirms via email after apply
      github_repository             = "OkiriGabriel/AWS-Terraform-Module-Applications"  # enables OIDC deploy role
      create_github_oidc_provider   = true   # false if the account already has the GitHub OIDC provider
    }
  }
}
```

CIS alarms cover: unauthorized API calls, console sign-in without MFA, root account usage, IAM policy
changes, CloudTrail config changes, console auth failures, KMS key disable/deletion, S3 bucket policy
changes, security group / NACL / network gateway / route table / VPC changes.

### GitHub Actions OIDC Deploy Role

Setting `security_features.github_repository` creates `cicd_oidc.tf`'s role, which only workflows on
`main` can assume. It can push to the three ECR repos, register task definitions, update services in the
prod cluster, and pass `<env>-*` roles to ECS tasks. Nothing else.

1. Apply, then copy output `github_actions_deploy_role_arn` into the repo secret `AWS_DEPLOY_ROLE_ARN`.
2. Rename `.github/workflows/deploy-ecs.yml.txt` to `deploy-ecs.yml`.
3. Delete the old `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets and deactivate that key.

Override `github_oidc_subjects` (e.g. `["repo:owner/repo:environment:production"]`) to narrow it further.

### Complete Security Suite

```hcl
# Enable all security features
module "guardduty" {
  source          = "./guardduty"
  name_prefix     = "${local.project_name}-guardduty"
  enable_notifications = true
  notification_emails  = ["security@example.com"]
  tags = local.tags
}

module "inspector" {
  source          = "./inspector"
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

| Area | Control |
|------|---------|
| Audit | Multi-region CloudTrail, KMS-encrypted, log file validation, TLS-only bucket, streamed to CloudWatch Logs |
| Detection | GuardDuty (S3, EBS malware, RDS logins), Inspector, Security Hub (FSBP + CIS v3.0), AWS Config, IAM Access Analyzer, 13 CIS alarms |
| Network | Private app/data tiers, VPC Flow Logs, WAF on the ALB, no SSH from `0.0.0.0/0` (validation blocks it) |
| Edge / TLS | ALB `ELBSecurityPolicy-TLS13-1-2-2021-06`, HTTP to HTTPS redirect, invalid headers dropped, CloudFront TLSv1.2_2021 |
| Data at rest | RDS storage encryption, EFS, S3 (SSE-S3 or SSE-KMS), DynamoDB, backup vault KMS, EBS encryption by default |
| Data in transit | S3 bucket policies deny non-TLS requests; EFS mounts use TLS from ECS tasks |
| Secrets | RDS master password managed and rotated by RDS in Secrets Manager; IAM DB auth enabled |
| Compute | IMDSv2 required, encrypted gp3 root volumes, SSM Session Manager (no SSH keys needed) |
| S3 | Public access block, ACLs disabled (`BucketOwnerEnforced`), versioning on backups/configs |
| CI/CD | OIDC deploy role (no static keys), Gitleaks secret scan, Checkov SARIF in GitHub code scanning |

### Shell Access Without SSH

Port 22 is closed everywhere by default. Use SSM Session Manager:

```bash
aws ssm start-session --target i-0123456789abcdef0

# Reach Grafana on the dev monitoring box without opening any port:
aws ssm start-session --target i-0123456789abcdef0 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'
```

If you need direct access, list specific CIDRs. `0.0.0.0/0` is rejected by variable validation:
- ECS hosts: `security.ssh_ingress_cidrs = ["203.0.113.10/32"]`
- Dev monitoring UIs: `monitoring.admin_cidr_blocks = ["203.0.113.10/32"]`

### Best Practices

1. **Never commit secrets**: Gitleaks runs on every push and PR
2. **Enable MFA**: The CIS alarm `console-signin-without-mfa` fires when someone skips it
3. **Use IAM roles**: The OIDC role replaces CI access keys
4. **Subscribe to alerts**: Set `security_features.alert_email` and confirm the subscription
5. **Review Security Hub**: Triage FSBP/CIS findings weekly
6. **Test restores**: AWS Backup runs daily/weekly; restore-test on a schedule

## Upgrade Notes

Read these before you run `terraform apply` on an existing environment. Always review `terraform plan` first.

- **RDS storage encryption** (`storage_encrypted = true`) cannot be enabled in place. On an existing unencrypted
  prod DB the plan shows a replacement; deletion protection makes that apply fail instead of destroying data.
  To migrate: snapshot, copy the snapshot with encryption, restore, cut over. Until then you can set
  `rds.storage_encrypted = false` in `vars_enviro_prod.tf`.
- **RDS settings are now honored.** The module used to hardcode `skip_final_snapshot = true`, the backup windows,
  and Multi-AZ. Prod now takes a final snapshot on destroy and keeps Multi-AZ (`rds.multi_az = true`).
- **RDS master password** moves to an RDS-managed Secrets Manager secret (output `database_master_secret_arn`).
  Applications that read the old password must read that secret instead.
- **GuardDuty**: prod used to declare a second detector in `security_enhancements.tf`, which AWS rejects (one per
  region). Only `module.guardduty`'s detector remains. If the old one is in your state, run
  `terraform state rm aws_guardduty_detector.example` before applying.
- **AWS Config bucket policy** moved into the S3 module. A `moved` block handles the state move automatically.
- **SSH** is closed on ECS hosts and the monitoring server. Dev monitoring UIs are no longer public unless you set
  `monitoring.admin_cidr_blocks`.
- **ECS backend/admin** task definitions no longer get an empty EFS volume (that broke task registration).

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

Configure SNS topics in your environment files for notifications. Set `security_features.alert_email`
to subscribe an inbox to the shared alerts topic (CIS alarms, DR alarms, service alarms).

## CI/CD

`.github/workflows/terraform-ci.yml` runs on pushes and PRs to `main`, `development`, `staging`:

| Job | What it checks |
|-----|----------------|
| Terraform Validation | `fmt -check`, `init`, `validate` for both dev and prod workspaces, TFLint, module layout |
| Secret Scanning | Gitleaks over full git history |
| IaC Security Scanning | Checkov, results uploaded to the repository's **Security > Code scanning** tab |

Run the same checks locally:

```bash
terraform fmt -recursive
terraform validate
checkov -d . --framework terraform
```

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
- [x] AWS Backup plan with KMS-encrypted vault
- [x] AWS WAF configuration
- [x] CloudTrail + CIS Benchmark alarms
- [x] GitHub Actions OIDC deploy role
- [ ] ElastiCache replication group with at-rest + in-transit encryption and AUTH
- [ ] ALB access logs to S3
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
