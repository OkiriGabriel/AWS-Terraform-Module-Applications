variable "name" {
  description = "Name prefix for all VPC resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "AZs to spread subnets across (one public + one private subnet per AZ)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ"
  type        = list(string)
}

variable "nat_mode" {
  description = "none | single | per_az"
  type        = string
  default     = "single"

  validation {
    condition     = contains(["none", "single", "per_az"], var.nat_mode)
    error_message = "nat_mode must be none, single or per_az."
  }
}

variable "enable_interface_endpoints" {
  description = "Create private interface endpoints for var.interface_endpoint_services"
  type        = bool
  default     = false
}

variable "interface_endpoint_services" {
  description = "Interface endpoint service suffixes"
  type        = list(string)
  default     = ["ecr.api", "ecr.dkr", "logs", "secretsmanager", "ssm", "ssmmessages", "ec2messages", "sts", "kms"]
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention for VPC flow logs"
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "KMS key for the flow log group (null = CloudWatch default encryption)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}
