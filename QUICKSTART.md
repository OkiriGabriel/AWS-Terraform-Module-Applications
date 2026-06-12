# Quick Start Guide

Get up and running with Gabriel AWS Infrastructure Boilerplate in minutes!

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0.0 installed
- AWS CLI configured with credentials
- Git installed

## 5-Minute Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/gabriel-aws-infrastructure.git
cd gabriel-aws-infrastructure
```

### 2. Configure Backend

Edit `provider.tf` to use your Terraform backend:

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}
```

Or remove the cloud/backend block to use local state (not recommended for production).

### 3. Customize Variables

Edit `vars_enviro_dev.tf` for development or `vars_enviro_prod.tf` for production:

```hcl
locals {
  dev = {
    environment  = "dev"
    project_name = "my-project"  # Change this
    
    vpc = {
      cidr            = "10.0.0.0/16"
      public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
      private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]
      azs             = ["us-east-1a", "us-east-1b"]
    }
    
    # Update S3 bucket names to be globally unique
    s3 = {
      buckets = {
        media = {
          name = "your-unique-media-bucket-name"  # Change this
          # ...
        }
      }
    }
  }
}
```

### 4. Initialize Terraform

```bash
terraform init
```

### 5. Create a Workspace (Optional)

```bash
terraform workspace new dev
terraform workspace select dev
```

### 6. Review the Plan

```bash
terraform plan
```

### 7. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm.

## What Gets Created?

### Core Infrastructure (Default)

- **VPC**: Multi-AZ VPC with public and private subnets
- **Security Groups**: Layered security with least privilege
- **RDS**: MySQL database with automated backups
- **ElastiCache**: Redis cluster for caching
- **S3 Buckets**: For media, static assets, backups, configs
- **ALB**: Application Load Balancer with SSL/TLS
- **ECS**: Container orchestration (if configured)
- **CloudWatch**: Monitoring and logging
- **Secrets Manager**: Secure credential storage

### Optional Modules

Enable additional modules by configuring them:

#### EKS Cluster

```hcl
module "eks" {
  source = "./modules/eks"

  cluster_name = "my-cluster"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
  
  node_groups = {
    general = {
      desired_size   = 2
      instance_types = ["t3.medium"]
    }
  }
}
```

#### GuardDuty

```hcl
module "guardduty" {
  source = "./modules/guardduty"

  enable_notifications = true
  notification_emails  = ["security@example.com"]
}
```

#### Inspector

```hcl
module "inspector" {
  source = "./modules/inspector"

  resource_types = ["EC2", "ECR", "LAMBDA"]
}
```

#### VPC Peering

```hcl
module "vpc_peering" {
  source = "./modules/vpc_peering"

  requester_vpc_id     = module.vpc_primary.vpc_id
  accepter_vpc_id      = module.vpc_secondary.vpc_id
  requester_cidr_block = "10.0.0.0/16"
  accepter_cidr_block  = "10.1.0.0/16"
}
```

#### VPN

```hcl
module "vpn" {
  source = "./modules/vpn"

  vpc_id                      = module.vpc.vpc_id
  create_site_to_site_vpn     = true
  customer_gateway_ip_address = "your.public.ip"
}
```

#### Transit Gateway

```hcl
module "transit_gateway" {
  source = "./modules/transit_gateway"

  name = "main-tgw"
  
  vpc_attachments = {
    vpc1 = {
      vpc_id     = module.vpc1.vpc_id
      subnet_ids = module.vpc1.private_subnet_ids
    }
  }
}
```

## Common Commands

### View Current State

```bash
terraform show
```

### View Outputs

```bash
terraform output
```

### Update Infrastructure

```bash
terraform plan
terraform apply
```

### Destroy Infrastructure

```bash
terraform destroy
```

### Format Code

```bash
terraform fmt -recursive
```

### Validate Configuration

```bash
terraform validate
```

## Access Your Resources

### View VPC

```bash
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*your-project*"
```

### View EKS Cluster (if created)

```bash
aws eks list-clusters
aws eks update-kubeconfig --name your-cluster-name --region us-east-1
kubectl get nodes
```

### View RDS Endpoint

```bash
terraform output rds_endpoint
```

### View S3 Buckets

```bash
aws s3 ls | grep your-project
```

## Troubleshooting

### Issue: Terraform Init Fails

**Solution**: Check your AWS credentials and backend configuration.

```bash
aws sts get-caller-identity
```

### Issue: S3 Bucket Name Conflicts

**Solution**: S3 bucket names must be globally unique. Update the bucket names in your environment file.

### Issue: Resource Quota Exceeded

**Solution**: Request limit increases in the AWS Service Quotas console.

### Issue: Permission Denied

**Solution**: Ensure your IAM user/role has sufficient permissions. See README for required permissions.

### Issue: State Lock

**Solution**: If using S3 backend with DynamoDB lock:

```bash
# View locks
aws dynamodb scan --table-name terraform-lock-table

# If needed, manually release the lock (use with caution)
terraform force-unlock <lock-id>
```

## Next Steps

1. **Review Security**: Run security scanning tools
   ```bash
   tfsec .
   checkov -d .
   ```

2. **Set Up CI/CD**: Configure GitHub Actions or GitLab CI for automated deployments

3. **Enable Monitoring**: Configure CloudWatch dashboards and alarms

4. **Set Up Backups**: Verify automated backup configurations

5. **Document Changes**: Keep track of customizations

6. **Join Community**: Participate in discussions and contribute

## Best Practices

1. **Never Commit Secrets**: Use Secrets Manager or environment variables
2. **Use Remote State**: Store state in S3 with DynamoDB locking
3. **Version Control**: Commit infrastructure changes with descriptive messages
4. **Test Changes**: Always run `terraform plan` before `apply`
5. **Use Workspaces**: Separate dev, staging, and production
6. **Tag Resources**: Use consistent tagging for cost allocation
7. **Review Costs**: Monitor AWS costs regularly
8. **Backup State**: Regularly backup your Terraform state file
9. **Document Customizations**: Keep notes on why changes were made
10. **Stay Updated**: Keep Terraform and providers up to date

## Example: Complete Dev Environment

Here's a complete example for a development environment:

```bash
# 1. Clone and configure
git clone https://github.com/yourusername/gabriel-aws-infrastructure.git
cd gabriel-aws-infrastructure

# 2. Edit vars_enviro_dev.tf
# Update project_name, S3 bucket names, and domain

# 3. Initialize
terraform init

# 4. Create workspace
terraform workspace new dev

# 5. Plan
terraform plan -out=tfplan

# 6. Apply
terraform apply tfplan

# 7. View outputs
terraform output

# 8. Access resources
aws eks update-kubeconfig --name my-cluster --region us-east-1
kubectl get all --all-namespaces
```

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/gabriel-aws-infrastructure/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/gabriel-aws-infrastructure/discussions)
- **Documentation**: [Project Wiki](https://github.com/yourusername/gabriel-aws-infrastructure/wiki)

## Additional Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

Happy Infrastructure as Code! 🚀
