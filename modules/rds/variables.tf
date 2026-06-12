variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the RDS instance will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS subnet group"
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "List of security group IDs allowed to access RDS"
  type        = list(string)
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage in GB"
  type        = number
}

variable "db_name" {
  description = "Name of the database"
  type        = string
}

# variable "db_username" {
#   description = "Username for the database"
#   type        = string
# }

variable "db_password" {
  description = "Password for the database"
  type        = string
  sensitive   = true
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ deployment"
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot when destroying"
  type        = bool
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
}

variable "backup_window" {
  description = "Preferred backup window"
  type        = string
}

variable "maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
}

variable "db_parameters" {
  description = "Map of DB parameters to apply"
  type        = list(map(string))
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
}

variable "engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"
}

variable "engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "8.0"
}

variable "port" {
  description = "Database port"
  type        = number
  default     = 3306
}

variable "db_username" {
  description = "Username for the master DB user"
  type        = string
}

# variable "db_password" {
#   description = "Password for the master DB user"
#   type        = string
#   sensitive   = true
# }
variable "security_group_id" {
  description = "Security group ID for the RDS instance"
  type        = string
}

