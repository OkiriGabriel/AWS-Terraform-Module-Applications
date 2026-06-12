variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for monitoring server"
  type        = string
  default     = "t2.small"
}

variable "ami_id" {
  description = "AMI ID for monitoring server"
  type        = string
}

variable "key_name" {
  description = "Key pair name for SSH access"
  type        = string
}

variable "services" {
  description = "Monitoring services configuration"
  type = object({
    prometheus = object({
      port = number
      path = string
    })
    grafana = object({
      port = number
      path = string
    })
    blackbox = object({
      port = number
      path = string
    })
    sonarqube = object({
      port = number
      path = string
    })
  })
}

variable "alb_security_group_id" {
  description = "ALB security group ID (prod: Grafana/Sonar ingress from ALB). Ignored when use_public_ip is true."
  type        = string
  default     = ""
}

# Dev (no ALB): public subnets + public IP + open SG on stack ports. Prod: false = private subnets + ALB-only UI paths.
variable "use_public_ip" {
  description = "If true, ASG uses public subnets, instances get a public IP, and monitoring ports are open to 0.0.0.0/0 (dev without ALB)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}