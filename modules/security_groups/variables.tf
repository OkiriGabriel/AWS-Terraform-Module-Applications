variable "name" {
  description = "Name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "service_ports" {
  description = "Container ports the ALB forwards to"
  type        = list(number)
  default     = []
}

variable "alb_ingress_cidrs" {
  description = "CIDRs allowed to reach the ALB on 80/443"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
