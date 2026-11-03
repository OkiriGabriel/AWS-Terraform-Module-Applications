# Site-to-Site VPN Outputs
output "customer_gateway_id" {
  description = "ID of the customer gateway"
  value       = try(aws_customer_gateway.main[0].id, "")
}

output "vpn_gateway_id" {
  description = "ID of the VPN gateway"
  value       = try(aws_vpn_gateway.main[0].id, "")
}

output "vpn_connection_id" {
  description = "ID of the VPN connection"
  value       = try(aws_vpn_connection.main[0].id, "")
}

output "vpn_connection_customer_gateway_configuration" {
  description = "Configuration information for the VPN connection"
  value       = try(aws_vpn_connection.main[0].customer_gateway_configuration, "")
  sensitive   = true
}

output "vpn_connection_tunnel1_address" {
  description = "Public IP address of tunnel 1"
  value       = try(aws_vpn_connection.main[0].tunnel1_address, "")
}

output "vpn_connection_tunnel2_address" {
  description = "Public IP address of tunnel 2"
  value       = try(aws_vpn_connection.main[0].tunnel2_address, "")
}

output "vpn_connection_tunnel1_preshared_key" {
  description = "Preshared key of tunnel 1"
  value       = try(aws_vpn_connection.main[0].tunnel1_preshared_key, "")
  sensitive   = true
}

output "vpn_connection_tunnel2_preshared_key" {
  description = "Preshared key of tunnel 2"
  value       = try(aws_vpn_connection.main[0].tunnel2_preshared_key, "")
  sensitive   = true
}

# Client VPN Outputs
output "client_vpn_endpoint_id" {
  description = "ID of the Client VPN endpoint"
  value       = try(aws_ec2_client_vpn_endpoint.main[0].id, "")
}

output "client_vpn_endpoint_arn" {
  description = "ARN of the Client VPN endpoint"
  value       = try(aws_ec2_client_vpn_endpoint.main[0].arn, "")
}

output "client_vpn_endpoint_dns_name" {
  description = "DNS name of the Client VPN endpoint"
  value       = try(aws_ec2_client_vpn_endpoint.main[0].dns_name, "")
}

output "client_vpn_network_associations" {
  description = "IDs of Client VPN network associations"
  value       = try(aws_ec2_client_vpn_network_association.main[*].id, [])
}

output "client_vpn_cloudwatch_log_group" {
  description = "Name of the CloudWatch log group for Client VPN"
  value       = try(aws_cloudwatch_log_group.client_vpn[0].name, "")
}

# Monitoring Outputs
output "tunnel1_alarm_arn" {
  description = "ARN of the tunnel 1 state alarm"
  value       = try(aws_cloudwatch_metric_alarm.tunnel1_state[0].arn, "")
}

output "tunnel2_alarm_arn" {
  description = "ARN of the tunnel 2 state alarm"
  value       = try(aws_cloudwatch_metric_alarm.tunnel2_state[0].arn, "")
}

output "client_vpn_connections_alarm_arn" {
  description = "ARN of the Client VPN connections alarm"
  value       = try(aws_cloudwatch_metric_alarm.client_vpn_connections[0].arn, "")
}
