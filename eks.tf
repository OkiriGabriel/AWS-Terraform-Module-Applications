# ============================================
# EKS  (stack includes "eks")
# ============================================
# API endpoint is private unless eks.public_access_cidrs is set (or the starter profile, which opens it
# publicly so you can kubectl without a VPN). Reach a private endpoint through client-vpn or transit-gateway.

locals {
  eks_public = local.has.eks && (length(var.eks.public_access_cidrs) > 0 || local.s.eks_public_endpoint)
}

module "eks" {
  source = "./modules/eks"
  count  = local.has.eks ? 1 : 0

  cluster_name    = local.prefix
  cluster_version = var.eks.version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids

  endpoint_private_access = true
  endpoint_public_access  = local.eks_public
  public_access_cidrs     = length(var.eks.public_access_cidrs) > 0 ? var.eks.public_access_cidrs : ["0.0.0.0/0"]

  node_groups = {
    general = {
      instance_types = var.eks.instance_types
      min_size       = var.eks.min_size
      desired_size   = var.eks.desired_size
      max_size       = var.eks.max_size
      capacity_type  = var.profile == "starter" ? "SPOT" : "ON_DEMAND"
    }
  }

  enable_encryption            = true
  enable_irsa                  = true
  enable_control_plane_logging = true
  log_retention_days           = local.s.log_retention
  enable_container_insights    = local.s.ecs_container_insights

  tags = local.tags
}
