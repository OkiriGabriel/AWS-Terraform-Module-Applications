variable "requester_vpc_id" {
  description = "The ID of the requester VPC"
  type        = string
}

variable "accepter_vpc_id" {
  description = "The ID of the accepter VPC"
  type        = string
}

variable "requester_cidr_block" {
  description = "CIDR block of the requester VPC (for routing)"
  type        = string
}

variable "accepter_cidr_block" {
  description = "CIDR block of the accepter VPC (for routing)"
  type        = string
}

variable "peer_owner_id" {
  description = "The AWS account ID of the owner of the peer VPC (for cross-account peering)"
  type        = string
  default     = null
}

variable "peer_region" {
  description = "The region of the accepter VPC (for cross-region peering)"
  type        = string
  default     = null
}

variable "auto_accept" {
  description = "Accept the peering request automatically (only works for same account and region)"
  type        = bool
  default     = true
}

variable "peering_name" {
  description = "Name tag for the peering connection"
  type        = string
  default     = null
}

variable "requester_route_table_ids" {
  description = "List of route table IDs in the requester VPC to add routes to"
  type        = list(string)
  default     = []
}

variable "accepter_route_table_ids" {
  description = "List of route table IDs in the accepter VPC to add routes to"
  type        = list(string)
  default     = []
}

variable "requester_allow_remote_vpc_dns_resolution" {
  description = "Allow requester VPC to resolve public DNS hostnames to private IP addresses when queried from instances in the accepter VPC"
  type        = bool
  default     = true
}

variable "accepter_allow_remote_vpc_dns_resolution" {
  description = "Allow accepter VPC to resolve public DNS hostnames to private IP addresses when queried from instances in the requester VPC"
  type        = bool
  default     = true
}

variable "create_security_group_rules" {
  description = "Create security group rules to allow traffic between peered VPCs"
  type        = bool
  default     = false
}

variable "requester_security_group_ids" {
  description = "List of security group IDs in the requester VPC to add ingress rules to"
  type        = list(string)
  default     = []
}

variable "accepter_security_group_ids" {
  description = "List of security group IDs in the accepter VPC to add ingress rules to"
  type        = list(string)
  default     = []
}

variable "configure_peering_options" {
  description = "Configure additional peering connection options"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring for the peering connection"
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
