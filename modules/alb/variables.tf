variable "environment" {
  description = "Environment name"
  type        = string
}

variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "internal" {
  description = "Whether the ALB is internal"
  type        = bool
  default     = false
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "target_port" {
  description = "Target port for the ALB"
  type        = number
}

variable "listener_port" {
  description = "Listener port for the ALB"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = null
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
  default     = null
}

variable "max_capacity" {
  description = "Maximum capacity for auto scaling"
  type        = number
}

variable "min_capacity" {
  description = "Minimum capacity for auto scaling"
  type        = number
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
} 