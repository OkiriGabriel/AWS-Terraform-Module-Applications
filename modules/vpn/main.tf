# VPN Module
# Supports both Site-to-Site VPN and Client VPN configurations

# -----------------
# Site-to-Site VPN
# -----------------

# Customer Gateway
resource "aws_customer_gateway" "main" {
  count      = var.create_site_to_site_vpn ? 1 : 0
  bgp_asn    = var.customer_gateway_bgp_asn
  ip_address = var.customer_gateway_ip_address
  type       = "ipsec.1"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-customer-gateway"
    }
  )
}

# Virtual Private Gateway
resource "aws_vpn_gateway" "main" {
  count           = var.create_site_to_site_vpn && var.use_transit_gateway == false ? 1 : 0
  vpc_id          = var.vpc_id
  amazon_side_asn = var.amazon_side_asn

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpn-gateway"
    }
  )
}

# VPN Gateway Attachment
resource "aws_vpn_gateway_attachment" "main" {
  count          = var.create_site_to_site_vpn && var.use_transit_gateway == false ? 1 : 0
  vpc_id         = var.vpc_id
  vpn_gateway_id = aws_vpn_gateway.main[0].id
}

# VPN Gateway Route Propagation
resource "aws_vpn_gateway_route_propagation" "main" {
  count          = var.create_site_to_site_vpn && var.use_transit_gateway == false ? length(var.route_table_ids) : 0
  vpn_gateway_id = aws_vpn_gateway.main[0].id
  route_table_id = var.route_table_ids[count.index]
}

# Site-to-Site VPN Connection
resource "aws_vpn_connection" "main" {
  count               = var.create_site_to_site_vpn ? 1 : 0
  customer_gateway_id = aws_customer_gateway.main[0].id
  type                = "ipsec.1"

  vpn_gateway_id      = var.use_transit_gateway == false ? aws_vpn_gateway.main[0].id : null
  transit_gateway_id  = var.use_transit_gateway ? var.transit_gateway_id : null

  static_routes_only  = var.static_routes_only
  tunnel1_inside_cidr = var.tunnel1_inside_cidr
  tunnel2_inside_cidr = var.tunnel2_inside_cidr

  tunnel1_preshared_key = var.tunnel1_preshared_key
  tunnel2_preshared_key = var.tunnel2_preshared_key

  tunnel1_dpd_timeout_action = var.tunnel_dpd_timeout_action
  tunnel2_dpd_timeout_action = var.tunnel_dpd_timeout_action

  tunnel1_ike_versions = var.tunnel_ike_versions
  tunnel2_ike_versions = var.tunnel_ike_versions

  tunnel1_phase1_dh_group_numbers      = var.tunnel_phase1_dh_group_numbers
  tunnel2_phase1_dh_group_numbers      = var.tunnel_phase1_dh_group_numbers
  tunnel1_phase1_encryption_algorithms = var.tunnel_phase1_encryption_algorithms
  tunnel2_phase1_encryption_algorithms = var.tunnel_phase1_encryption_algorithms
  tunnel1_phase1_integrity_algorithms  = var.tunnel_phase1_integrity_algorithms
  tunnel2_phase1_integrity_algorithms  = var.tunnel_phase1_integrity_algorithms

  tunnel1_phase2_dh_group_numbers      = var.tunnel_phase2_dh_group_numbers
  tunnel2_phase2_dh_group_numbers      = var.tunnel_phase2_dh_group_numbers
  tunnel1_phase2_encryption_algorithms = var.tunnel_phase2_encryption_algorithms
  tunnel2_phase2_encryption_algorithms = var.tunnel_phase2_encryption_algorithms
  tunnel1_phase2_integrity_algorithms  = var.tunnel_phase2_integrity_algorithms
  tunnel2_phase2_integrity_algorithms  = var.tunnel_phase2_integrity_algorithms

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpn-connection"
    }
  )
}

# Static Routes for VPN Connection
resource "aws_vpn_connection_route" "main" {
  count                  = var.create_site_to_site_vpn && var.static_routes_only ? length(var.static_routes) : 0
  vpn_connection_id      = aws_vpn_connection.main[0].id
  destination_cidr_block = var.static_routes[count.index]
}

# -----------------
# Client VPN
# -----------------

# Client VPN Endpoint
resource "aws_ec2_client_vpn_endpoint" "main" {
  count                  = var.create_client_vpn ? 1 : 0
  description            = var.client_vpn_description
  server_certificate_arn = var.server_certificate_arn
  client_cidr_block      = var.client_cidr_block
  split_tunnel           = var.split_tunnel
  dns_servers            = var.dns_servers
  transport_protocol     = var.transport_protocol
  vpn_port               = var.vpn_port

  authentication_options {
    type                       = var.authentication_type
    root_certificate_chain_arn = var.authentication_type == "certificate-authentication" ? var.client_root_certificate_arn : null
    active_directory_id        = var.authentication_type == "directory-service-authentication" ? var.active_directory_id : null
    saml_provider_arn          = var.authentication_type == "federated-authentication" ? var.saml_provider_arn : null
  }

  connection_log_options {
    enabled               = var.enable_connection_logging
    cloudwatch_log_group  = var.enable_connection_logging ? aws_cloudwatch_log_group.client_vpn[0].name : null
    cloudwatch_log_stream = var.enable_connection_logging ? aws_cloudwatch_log_stream.client_vpn[0].name : null
  }

  security_group_ids = var.client_vpn_security_group_ids
  vpc_id             = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-client-vpn-endpoint"
    }
  )
}

# Client VPN Network Association
resource "aws_ec2_client_vpn_network_association" "main" {
  count                  = var.create_client_vpn ? length(var.client_vpn_subnet_ids) : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main[0].id
  subnet_id              = var.client_vpn_subnet_ids[count.index]

  lifecycle {
    ignore_changes = [subnet_id]
  }
}

# Client VPN Authorization Rule
resource "aws_ec2_client_vpn_authorization_rule" "main" {
  count                  = var.create_client_vpn ? length(var.client_vpn_authorization_rules) : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main[0].id
  target_network_cidr    = var.client_vpn_authorization_rules[count.index].target_network_cidr
  authorize_all_groups   = lookup(var.client_vpn_authorization_rules[count.index], "authorize_all_groups", true)
  access_group_id        = lookup(var.client_vpn_authorization_rules[count.index], "access_group_id", null)
  description            = lookup(var.client_vpn_authorization_rules[count.index], "description", null)
}

# Client VPN Route
resource "aws_ec2_client_vpn_route" "main" {
  count                  = var.create_client_vpn ? length(var.client_vpn_routes) : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main[0].id
  destination_cidr_block = var.client_vpn_routes[count.index].destination_cidr_block
  target_vpc_subnet_id   = var.client_vpn_routes[count.index].target_vpc_subnet_id
  description            = lookup(var.client_vpn_routes[count.index], "description", null)

  depends_on = [aws_ec2_client_vpn_network_association.main]
}

# CloudWatch Log Group for Client VPN
resource "aws_cloudwatch_log_group" "client_vpn" {
  count             = var.create_client_vpn && var.enable_connection_logging ? 1 : 0
  name              = "/aws/clientvpn/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_stream" "client_vpn" {
  count          = var.create_client_vpn && var.enable_connection_logging ? 1 : 0
  name           = "${var.name_prefix}-connection-log"
  log_group_name = aws_cloudwatch_log_group.client_vpn[0].name
}

# -----------------
# Monitoring
# -----------------

# CloudWatch Alarm for VPN Tunnel State
resource "aws_cloudwatch_metric_alarm" "tunnel1_state" {
  count               = var.create_site_to_site_vpn && var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.name_prefix}-vpn-tunnel1-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TunnelState"
  namespace           = "AWS/VPN"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "VPN Tunnel 1 is down"
  treat_missing_data  = "breaching"

  dimensions = {
    VpnId = aws_vpn_connection.main[0].id
    TunnelIpAddress = aws_vpn_connection.main[0].tunnel1_address
  }

  alarm_actions = var.alarm_actions

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "tunnel2_state" {
  count               = var.create_site_to_site_vpn && var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.name_prefix}-vpn-tunnel2-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TunnelState"
  namespace           = "AWS/VPN"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "VPN Tunnel 2 is down"
  treat_missing_data  = "breaching"

  dimensions = {
    VpnId = aws_vpn_connection.main[0].id
    TunnelIpAddress = aws_vpn_connection.main[0].tunnel2_address
  }

  alarm_actions = var.alarm_actions

  tags = var.tags
}

# CloudWatch Alarm for Client VPN Active Connections
resource "aws_cloudwatch_metric_alarm" "client_vpn_connections" {
  count               = var.create_client_vpn && var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.name_prefix}-client-vpn-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ActiveConnectionsCount"
  namespace           = "AWS/ClientVPN"
  period              = 300
  statistic           = "Average"
  threshold           = var.client_vpn_connection_threshold
  alarm_description   = "Client VPN active connections exceeds threshold"

  dimensions = {
    Endpoint = aws_ec2_client_vpn_endpoint.main[0].id
  }

  alarm_actions = var.alarm_actions

  tags = var.tags
}
