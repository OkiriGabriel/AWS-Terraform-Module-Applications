variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "secret_name" {
  description = "Name of the secret in AWS Secrets Manager"
  type        = string
}

variable "secret_description" {
  description = "Description of the secret"
  type        = string
}

variable "engine" {
  description = "Database engine (e.g., postgres, mysql)"
  type        = string
  default     = "postgres"
}

# variable "host" {
#   description = "Database host"
#   type        = string
# }

# variable "port" {
#   description = "Database port"
#   type        = number
#   default     = 5432
# }

# variable "dbname" {
#   description = "Database name"
#   type        = string
# }

variable "tags" {
  description = "Tags to apply to the secret"
  type        = map(string)
  default     = {}
} 