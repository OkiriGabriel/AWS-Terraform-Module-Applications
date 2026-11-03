variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "vpn"
}

variable "vpc_id" {
  description = "VPC ID where VPN will be deployed"
  type        = string
}

# -----------------
# Site-to-Site VPN Variables
# -----------------

variable "create_site_to_site_vpn" {
  description = "Create Site-to-Site VPN connection"
  type        = bool
  default     = false
}

variable "customer_gateway_ip_address" {
  description = "IP address of the customer gateway"
  type        = string
  default     = null
}

variable "customer_gateway_bgp_asn" {
  description = "BGP ASN of the customer gateway"
  type        = number
  default     = 65000
}

variable "amazon_side_asn" {
  description = "ASN for the Amazon side of the VPN gateway"
  type        = number
  default     = 64512
}

variable "use_transit_gateway" {
  description = "Use Transit Gateway instead of Virtual Private Gateway"
  type        = bool
  default     = false
}

variable "transit_gateway_id" {
  description = "ID of the Transit Gateway (if using)"
  type        = string
  default     = null
}

variable "route_table_ids" {
  description = "List of route table IDs for VPN route propagation"
  type        = list(string)
  default     = []
}

variable "static_routes_only" {
  description = "Use static routing instead of BGP"
  type        = bool
  default     = false
}

variable "static_routes" {
  description = "List of static routes for VPN connection"
  type        = list(string)
  default     = []
}

variable "tunnel1_inside_cidr" {
  description = "Inside CIDR for tunnel 1"
  type        = string
  default     = null
}

variable "tunnel2_inside_cidr" {
  description = "Inside CIDR for tunnel 2"
  type        = string
  default     = null
}

variable "tunnel1_preshared_key" {
  description = "Preshared key for tunnel 1"
  type        = string
  default     = null
  sensitive   = true
}

variable "tunnel2_preshared_key" {
  description = "Preshared key for tunnel 2"
  type        = string
  default     = null
  sensitive   = true
}

variable "tunnel_dpd_timeout_action" {
  description = "Action to take after DPD timeout (clear, none, restart)"
  type        = string
  default     = "clear"
}

variable "tunnel_ike_versions" {
  description = "IKE versions for VPN tunnels"
  type        = list(string)
  default     = ["ikev2"]
}

variable "tunnel_phase1_dh_group_numbers" {
  description = "Phase 1 DH group numbers"
  type        = list(number)
  default     = [14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]
}

variable "tunnel_phase1_encryption_algorithms" {
  description = "Phase 1 encryption algorithms"
  type        = list(string)
  default     = ["AES256", "AES128", "AES256-GCM-16"]
}

variable "tunnel_phase1_integrity_algorithms" {
  description = "Phase 1 integrity algorithms"
  type        = list(string)
  default     = ["SHA2-256", "SHA2-384", "SHA2-512"]
}

variable "tunnel_phase2_dh_group_numbers" {
  description = "Phase 2 DH group numbers"
  type        = list(number)
  default     = [14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]
}

variable "tunnel_phase2_encryption_algorithms" {
  description = "Phase 2 encryption algorithms"
  type        = list(string)
  default     = ["AES256", "AES128", "AES256-GCM-16"]
}

variable "tunnel_phase2_integrity_algorithms" {
  description = "Phase 2 integrity algorithms"
  type        = list(string)
  default     = ["SHA2-256", "SHA2-384", "SHA2-512"]
}

# -----------------
# Client VPN Variables
# -----------------

variable "create_client_vpn" {
  description = "Create Client VPN endpoint"
  type        = bool
  default     = false
}

variable "client_vpn_description" {
  description = "Description for the Client VPN endpoint"
  type        = string
  default     = "Client VPN Endpoint"
}

variable "server_certificate_arn" {
  description = "ARN of the server certificate"
  type        = string
  default     = null
}

variable "client_cidr_block" {
  description = "CIDR block for client VPN addresses"
  type        = string
  default     = "172.16.0.0/22"
}

variable "split_tunnel" {
  description = "Enable split tunnel mode"
  type        = bool
  default     = true
}

variable "dns_servers" {
  description = "DNS servers for Client VPN"
  type        = list(string)
  default     = []
}

variable "transport_protocol" {
  description = "Transport protocol (udp or tcp)"
  type        = string
  default     = "udp"
}

variable "vpn_port" {
  description = "VPN port number"
  type        = number
  default     = 443
}

variable "authentication_type" {
  description = "Authentication type (certificate-authentication, directory-service-authentication, federated-authentication)"
  type        = string
  default     = "certificate-authentication"
}

variable "client_root_certificate_arn" {
  description = "ARN of the client root certificate"
  type        = string
  default     = null
}

variable "active_directory_id" {
  description = "ID of the Active Directory (for directory-service-authentication)"
  type        = string
  default     = null
}

variable "saml_provider_arn" {
  description = "ARN of the SAML provider (for federated-authentication)"
  type        = string
  default     = null
}

variable "client_vpn_security_group_ids" {
  description = "Security group IDs for Client VPN endpoint"
  type        = list(string)
  default     = []
}

variable "client_vpn_subnet_ids" {
  description = "Subnet IDs to associate with Client VPN endpoint"
  type        = list(string)
  default     = []
}

variable "client_vpn_authorization_rules" {
  description = "Authorization rules for Client VPN"
  type = list(object({
    target_network_cidr  = string
    authorize_all_groups = optional(bool, true)
    access_group_id      = optional(string)
    description          = optional(string)
  }))
  default = []
}

variable "client_vpn_routes" {
  description = "Routes for Client VPN"
  type = list(object({
    destination_cidr_block = string
    target_vpc_subnet_id   = string
    description            = optional(string)
  }))
  default = []
}

variable "enable_connection_logging" {
  description = "Enable connection logging for Client VPN"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

# -----------------
# Monitoring
# -----------------

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

variable "client_vpn_connection_threshold" {
  description = "Threshold for Client VPN active connections alarm"
  type        = number
  default     = 100
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
