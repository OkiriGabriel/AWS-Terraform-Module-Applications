variable "name" {
  description = "Name of the Transit Gateway"
  type        = string
}

variable "description" {
  description = "Description of the Transit Gateway"
  type        = string
  default     = "Transit Gateway for VPC connectivity"
}

variable "amazon_side_asn" {
  description = "Private Autonomous System Number (ASN) for the Amazon side of a BGP session"
  type        = number
  default     = 64512
}

variable "default_route_table_association" {
  description = "Whether resource attachments are automatically associated with the default association route table"
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["enable", "disable"], var.default_route_table_association)
    error_message = "Must be either 'enable' or 'disable'."
  }
}

variable "default_route_table_propagation" {
  description = "Whether resource attachments automatically propagate routes to the default propagation route table"
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["enable", "disable"], var.default_route_table_propagation)
    error_message = "Must be either 'enable' or 'disable'."
  }
}

variable "dns_support" {
  description = "Whether DNS support is enabled"
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["enable", "disable"], var.dns_support)
    error_message = "Must be either 'enable' or 'disable'."
  }
}

variable "vpn_ecmp_support" {
  description = "Whether VPN Equal Cost Multipath Protocol support is enabled"
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["enable", "disable"], var.vpn_ecmp_support)
    error_message = "Must be either 'enable' or 'disable'."
  }
}

variable "auto_accept_shared_attachments" {
  description = "Whether resource attachment requests are automatically accepted"
  type        = string
  default     = "disable"

  validation {
    condition     = contains(["enable", "disable"], var.auto_accept_shared_attachments)
    error_message = "Must be either 'enable' or 'disable'."
  }
}

variable "transit_gateway_cidr_blocks" {
  description = "One or more IPv4 or IPv6 CIDR blocks for the transit gateway"
  type        = list(string)
  default     = []
}

variable "vpc_attachments" {
  description = "Map of VPC attachments"
  type = map(object({
    vpc_id                                          = string
    subnet_ids                                      = list(string)
    dns_support                                     = optional(string)
    ipv6_support                                    = optional(bool, false)
    appliance_mode_support                          = optional(bool, false)
    transit_gateway_default_route_table_association = optional(bool)
    transit_gateway_default_route_table_propagation = optional(bool)
    tags                                            = optional(map(string), {})
  }))
  default = {}
}

variable "transit_gateway_route_tables" {
  description = "Map of Transit Gateway route tables to create"
  type = map(object({
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "transit_gateway_route_table_associations" {
  description = "Map of Transit Gateway route table associations"
  type = map(object({
    vpc_attachment_id              = string
    transit_gateway_route_table_id = string
  }))
  default = {}
}

variable "transit_gateway_route_table_propagations" {
  description = "Map of Transit Gateway route table propagations"
  type = map(object({
    vpc_attachment_id              = string
    transit_gateway_route_table_id = string
  }))
  default = {}
}

variable "transit_gateway_routes" {
  description = "Map of Transit Gateway routes"
  type = map(object({
    destination_cidr_block         = string
    transit_gateway_route_table_id = string
    transit_gateway_attachment_id  = optional(string)
    blackhole                      = optional(bool, false)
  }))
  default = {}
}

variable "vpc_route_table_routes" {
  description = "Map of routes to add to VPC route tables pointing to the Transit Gateway"
  type = map(object({
    route_table_id         = string
    destination_cidr_block = string
  }))
  default = {}
}

variable "enable_resource_sharing" {
  description = "Enable resource sharing via RAM for cross-account access"
  type        = bool
  default     = false
}

variable "allow_external_principals" {
  description = "Whether to allow external principals in RAM share"
  type        = bool
  default     = false
}

variable "ram_principals" {
  description = "List of AWS principals (account IDs, organization ARNs, OU ARNs) to share the Transit Gateway with"
  type        = list(string)
  default     = []
}

variable "transit_gateway_peering_attachments" {
  description = "Map of Transit Gateway peering attachments for cross-region connectivity"
  type = map(object({
    peer_transit_gateway_id = string
    peer_region             = string
    peer_account_id         = optional(string)
    tags                    = optional(map(string), {})
  }))
  default = {}
}

variable "transit_gateway_peering_accepters" {
  description = "Map of Transit Gateway peering attachment accepters"
  type = map(object({
    transit_gateway_attachment_id = string
    tags                          = optional(map(string), {})
  }))
  default = {}
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for the Transit Gateway"
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain flow logs"
  type        = number
  default     = 30
}

variable "flow_logs_traffic_type" {
  description = "Type of traffic to log (ACCEPT, REJECT, ALL)"
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_logs_traffic_type)
    error_message = "Must be ACCEPT, REJECT, or ALL."
  }
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger"
  type        = list(string)
  default     = []
}

variable "bytes_in_threshold" {
  description = "Threshold for bytes in alarm (in bytes)"
  type        = number
  default     = 1000000000  # 1 GB
}

variable "bytes_out_threshold" {
  description = "Threshold for bytes out alarm (in bytes)"
  type        = number
  default     = 1000000000  # 1 GB
}

variable "packet_drop_threshold" {
  description = "Threshold for packet drop alarm"
  type        = number
  default     = 100
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
