# EKS Cluster Root Module
# Uncomment to enable EKS cluster

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
    # Add more node groups as needed
  }
  
  enable_irsa               = true
  enable_encryption         = true
  enable_container_insights = true
  enable_control_plane_logging = true
  
  tags = local.tags
}

# Outputs
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = try(module.eks.cluster_id, null)
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = try(module.eks.cluster_endpoint, null)
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = try(module.eks.cluster_name, null)
}

output "eks_kubeconfig" {
  description = "Kubectl config for EKS cluster"
  value       = try(module.eks.kubeconfig, null)
  sensitive   = true
}