# EKS Module

This module creates a production-ready Amazon EKS (Elastic Kubernetes Service) cluster with managed node groups.

## Features

- EKS Cluster with configurable Kubernetes version
- Managed Node Groups with auto-scaling
- IAM Roles for Service Accounts (IRSA) support
- KMS encryption for Kubernetes secrets
- CloudWatch Container Insights
- Control plane logging
- VPC CNI, CoreDNS, and kube-proxy add-ons
- Security groups for cluster and nodes
- OIDC provider for pod-level IAM roles

## Usage

```hcl
module "eks" {
  source = "./modules/eks"

  cluster_name    = "my-eks-cluster"
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
    
    spot = {
      desired_size   = 1
      min_size       = 0
      max_size       = 3
      instance_types = ["t3.medium", "t3a.medium"]
      capacity_type  = "SPOT"
      
      labels = {
        workload = "batch"
      }
      
      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NoSchedule"
      }]
    }
  }
  
  enable_irsa                = true
  enable_encryption          = true
  enable_container_insights  = true
  
  tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name of the EKS cluster | string | - | yes |
| cluster_version | Kubernetes version | string | "1.28" | no |
| vpc_id | VPC ID | string | - | yes |
| subnet_ids | List of subnet IDs | list(string) | - | yes |
| node_groups | Map of node group configurations | map(object) | See variables.tf | no |
| enable_encryption | Enable KMS encryption | bool | true | no |
| enable_irsa | Enable IAM Roles for Service Accounts | bool | true | no |
| enable_container_insights | Enable Container Insights | bool | true | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | EKS cluster ID |
| cluster_endpoint | EKS cluster endpoint |
| cluster_name | EKS cluster name |
| cluster_security_group_id | Cluster security group ID |
| node_security_group_id | Node security group ID |
| oidc_provider_arn | OIDC provider ARN for IRSA |
| kubeconfig | Kubectl configuration |

## Post-Deployment

After deployment, configure kubectl:

```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

Install additional components:

```bash
# AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name>

# Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Cluster Autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

## License

MIT
