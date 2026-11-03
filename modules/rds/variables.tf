variable "name" {
  description = "Name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the DB subnet group"
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "Map of static label => security group ID allowed to connect"
  type        = map(string)
  default     = {}
}

variable "engine" {
  description = "postgres or mysql"
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.engine)
    error_message = "engine must be postgres or mysql."
  }
}

variable "engine_version" {
  description = "Engine version (null = 16 for postgres, 8.0 for mysql)"
  type        = string
  default     = null
}

variable "instance_class" {
  description = "Instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Initial storage (GiB)"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling (GiB)"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "app"
}

variable "username" {
  description = "Master username (password is managed by RDS)"
  type        = string
  default     = "app_admin"
}

variable "parameters" {
  description = "Extra DB parameters (merged over the TLS-enforcing defaults)"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key (null = AWS-managed aws/rds)"
  type        = string
  default     = null
}

variable "multi_az" {
  description = "Multi-AZ standby"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Automated backup retention (days)"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Block deletion"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy"
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = false
}

variable "backup_tags" {
  description = "Tags that opt the instance into an AWS Backup plan"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
