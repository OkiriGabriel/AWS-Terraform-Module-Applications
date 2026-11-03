variable "name" {
  description = "Name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets"
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "Map of static label => security group ID allowed to connect"
  type        = map(string)
  default     = {}
}

variable "node_type" {
  description = "Node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "num_nodes" {
  description = "Number of nodes (>1 enables Multi-AZ automatic failover)"
  type        = number
  default     = 1
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "parameter_group_name" {
  description = "Parameter group"
  type        = string
  default     = "default.redis7"
}

variable "snapshot_retention_days" {
  description = "Daily snapshot retention (0 = off)"
  type        = number
  default     = 0
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key (null = AWS-managed)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
