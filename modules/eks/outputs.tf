output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version of the cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = aws_security_group.node_group.id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_arn" {
  description = "IAM role ARN of the EKS node groups"
  value       = aws_iam_role.node_group.arn
}

output "node_iam_role_name" {
  description = "IAM role name of the EKS node groups"
  value       = aws_iam_role.node_group.name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = try(aws_eks_cluster.main.identity[0].oidc[0].issuer, "")
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = try(aws_iam_openid_connect_provider.cluster[0].arn, "")
}

output "node_groups" {
  description = "Map of attribute maps for all EKS node groups created"
  value = {
    for k, v in aws_eks_node_group.main : k => {
      id               = v.id
      arn              = v.arn
      status           = v.status
      capacity_type    = v.capacity_type
      node_group_name  = v.node_group_name
      scaling_config   = v.scaling_config
      instance_types   = v.instance_types
    }
  }
}

output "kms_key_id" {
  description = "KMS key ID used for cluster encryption"
  value       = try(aws_kms_key.eks[0].id, "")
}

output "kms_key_arn" {
  description = "KMS key ARN used for cluster encryption"
  value       = try(aws_kms_key.eks[0].arn, "")
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for cluster logs"
  value       = try(aws_cloudwatch_log_group.cluster[0].name, "")
}

output "kubeconfig" {
  description = "kubectl config file contents for this EKS cluster"
  value = templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name                     = aws_eks_cluster.main.name
    cluster_endpoint                 = aws_eks_cluster.main.endpoint
    cluster_certificate_authority_data = aws_eks_cluster.main.certificate_authority[0].data
  })
  sensitive = true
}
