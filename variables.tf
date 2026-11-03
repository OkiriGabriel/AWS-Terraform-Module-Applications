# ============================================
# THE THREE DIALS
# ============================================

variable "name" {
  description = "Short project name used to prefix every resource (lowercase letters, digits, hyphens; max 12 chars)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,11}$", var.name))
    error_message = "name must be 2-12 chars: lowercase letters, digits, hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment label (e.g. dev, staging, prod). Max 8 chars."
  type        = string
  default     = "prod"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,7}$", var.environment))
    error_message = "environment must be 2-8 lowercase letters/digits, starting with a letter."
  }
}

variable "profile" {
  description = <<-EOT
    Preset bundle of defaults:
      starter    - lowest cost: single NAT, Fargate Spot, no WAF/backups, HTTP allowed without a domain
      production - Multi-AZ data, NAT per AZ, WAF, backups, Security Hub, Inspector, Config, CIS alarms
      regulated  - production + customer-managed KMS everywhere, 3 AZs, VPC interface endpoints,
                   7-year audit retention, backup vault lock, immutable images, no ECS Exec
  EOT
  type        = string
  default     = "production"

  validation {
    condition     = contains(["starter", "production", "regulated"], var.profile)
    error_message = "profile must be one of: starter, production, regulated."
  }
}

variable "stack" {
  description = "Components to deploy: ecs, eks, rds, redis, efs, cdn, vpn, client-vpn, transit-gateway."
  type        = set(string)
  default     = ["ecs"]

  validation {
    condition = alltrue([
      for s in var.stack : contains(["ecs", "eks", "rds", "redis", "efs", "cdn", "vpn", "client-vpn", "transit-gateway"], s)
    ])
    error_message = "Unknown stack component. Allowed: ecs, eks, rds, redis, efs, cdn, vpn, client-vpn, transit-gateway."
  }
}

# ============================================
# ESCAPE HATCH
# ============================================

variable "overrides" {
  description = "Override any resolved profile setting by key (see `settings` output for the full list), e.g. { rds_instance_class = \"db.r7g.large\" }."
  type        = any
  default     = {}
}

# ============================================
# OPTIONAL DETAIL (only needed for the components that use them)
# ============================================

variable "services" {
  description = <<-EOT
    ECS services (stack must include "ecs"). Key = short service name (max 10 chars).
    Every service gets an ECR repo, log group, autoscaling, ALB routing and, automatically, connection
    details for whatever data stores are in the stack (DB_*, REDIS_*, BUCKET_*, EFS mount).
  EOT
  type = map(object({
    image             = optional(string) # null = "<ecr repo>:latest"
    port              = optional(number, 80)
    cpu               = optional(number, 256)
    memory            = optional(number, 512)
    desired_count     = optional(number, 1)
    min_count         = optional(number, 1)
    max_count         = optional(number, 4)
    path_patterns     = optional(list(string), ["/*"]) # "/*" = catch-all (default route)
    host_headers      = optional(list(string), [])
    health_check_path = optional(string, "/")
    environment       = optional(map(string), {})
    secrets           = optional(map(string), {}) # NAME = Secrets Manager / SSM ARN
    efs_mount_path    = optional(string)          # requires "efs" in stack
    deployed_by_ci    = optional(bool)            # null = true when github_repository is set
  }))
  default = {
    web = {
      image = "public.ecr.aws/nginx/nginx:stable"
    }
  }

  validation {
    condition     = alltrue([for k in keys(var.services) : can(regex("^[a-z][a-z0-9]{0,9}$", k))])
    error_message = "Service keys must be 1-10 lowercase letters/digits (they become part of AWS resource names)."
  }
}

variable "domain" {
  description = <<-EOT
    Public domain for the load balancer. Provide certificate_arn, or zone_id to have the module issue
    and DNS-validate an ACM certificate and create the alias record. Required for production/regulated.
  EOT
  type = object({
    name            = string
    zone_id         = optional(string)
    certificate_arn = optional(string)
  })
  default = null
}

variable "network" {
  description = "VPC layout. Subnets are carved automatically from cidr."
  type = object({
    cidr           = optional(string, "10.0.0.0/16")
    az_count       = optional(number) # null = profile default (2, or 3 for regulated)
    subnet_newbits = optional(number, 4)
  })
  default = {}
}

variable "vpn" {
  description = "Site-to-Site VPN to an on-premises network (stack must include \"vpn\")."
  type = object({
    customer_gateway_ip = string
    bgp_asn             = optional(number, 65000)
    static_routes       = optional(list(string), []) # empty = BGP
  })
  default = null
}

variable "client_vpn" {
  description = "AWS Client VPN for remote users (stack must include \"client-vpn\"). Certificates must already be in ACM."
  type = object({
    server_certificate_arn      = string
    client_root_certificate_arn = optional(string) # mutual TLS
    saml_provider_arn           = optional(string) # SSO (alternative to client_root_certificate_arn)
    client_cidr                 = optional(string, "172.16.0.0/22")
    split_tunnel                = optional(bool, true)
  })
  default = null
}

variable "transit_gateway" {
  description = "Transit Gateway options (stack must include \"transit-gateway\")."
  type = object({
    amazon_side_asn       = optional(number, 64512)
    routes                = optional(list(string), ["10.0.0.0/8"]) # sent from this VPC to the TGW
    share_with_principals = optional(list(string), [])             # account IDs / OU ARNs via RAM
  })
  default = {}
}

variable "peerings" {
  description = "VPC peerings to create. Key = peering name."
  type = map(object({
    vpc_id          = string
    cidr            = string
    route_table_ids = optional(list(string), [])
    peer_owner_id   = optional(string)
    peer_region     = optional(string)
  }))
  default = {}
}

variable "buckets" {
  description = "Application S3 buckets. Services get BUCKET_<NAME> env vars and read/write access automatically."
  type = map(object({
    versioning = optional(bool, true)
  }))
  default = {}
}

variable "database" {
  description = "RDS engine choice (stack must include \"rds\"). Sizing comes from the profile; override via overrides."
  type = object({
    engine         = optional(string, "postgres")
    engine_version = optional(string) # null = 16 for postgres, 8.0 for mysql
    name           = optional(string, "app")
    parameters     = optional(map(string), {})
  })
  default = {}

  validation {
    condition     = contains(["postgres", "mysql"], var.database.engine)
    error_message = "database.engine must be postgres or mysql."
  }
}

variable "eks" {
  description = "EKS options (stack must include \"eks\")."
  type = object({
    version             = optional(string, "1.34")
    instance_types      = optional(list(string), ["t3.large"])
    min_size            = optional(number, 1)
    desired_size        = optional(number, 2)
    max_size            = optional(number, 5)
    public_access_cidrs = optional(list(string), []) # empty + profile allows public = 0.0.0.0/0 is NOT used; endpoint goes private
  })
  default = {}
}

variable "alert_email" {
  description = "Email subscribed to the alerts SNS topic (alarms, GuardDuty, Inspector). Required for regulated."
  type        = string
  default     = ""
}

variable "account_baseline" {
  description = <<-EOT
    Manage account/region singletons: GuardDuty, Security Hub, AWS Config, Inspector, CloudTrail,
    EBS encryption by default, Access Analyzer. Set false on all but one environment that shares an account,
    or when your organization manages them centrally.
  EOT
  type        = bool
  default     = true
}

variable "github_repository" {
  description = "\"owner/repo\" to create a GitHub Actions OIDC deploy role (push to ECR, deploy ECS). Empty = disabled."
  type        = string
  default     = ""
}

variable "github_oidc_subjects" {
  description = "Allowed OIDC `sub` patterns. Default: only the main branch of github_repository."
  type        = list(string)
  default     = []
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC identity provider. Set false if the account already has it."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
