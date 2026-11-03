# ============================================
# CONNECTIVITY: SITE-TO-SITE VPN, CLIENT VPN, TRANSIT GATEWAY, PEERING
# ============================================

# --------------------------------------------
# Transit Gateway  (stack includes "transit-gateway")
# --------------------------------------------
module "transit_gateway" {
  source = "./modules/transit_gateway"
  count  = local.has.transit_gateway ? 1 : 0

  name            = "${local.prefix}-tgw"
  description     = "${local.prefix} hub"
  amazon_side_asn = var.transit_gateway.amazon_side_asn

  vpc_attachments = {
    main = {
      vpc_id     = module.vpc.vpc_id
      subnet_ids = module.vpc.private_subnet_ids
    }
  }

  vpc_route_table_routes = {
    for pair in setproduct(range(local.az_count), var.transit_gateway.routes) :
    "rt${pair[0]}-${replace(pair[1], "/", "_")}" => {
      route_table_id         = module.vpc.private_route_table_ids[pair[0]]
      destination_cidr_block = pair[1]
    }
  }

  enable_resource_sharing   = length(var.transit_gateway.share_with_principals) > 0
  allow_external_principals = false
  ram_principals            = var.transit_gateway.share_with_principals

  enable_flow_logs         = true
  flow_logs_retention_days = local.s.flow_log_retention
  enable_monitoring        = true
  alarm_actions            = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --------------------------------------------
# Site-to-Site VPN  (stack includes "vpn")
# Terminates on the Transit Gateway when it exists, otherwise on a Virtual Private Gateway.
# --------------------------------------------
module "site_to_site_vpn" {
  source = "./modules/vpn"
  count  = local.has.vpn ? 1 : 0

  name_prefix = "${local.prefix}-s2s"
  vpc_id      = module.vpc.vpc_id

  create_site_to_site_vpn     = true
  customer_gateway_ip_address = var.vpn.customer_gateway_ip
  customer_gateway_bgp_asn    = var.vpn.bgp_asn

  use_transit_gateway = local.has.transit_gateway
  transit_gateway_id  = local.has.transit_gateway ? module.transit_gateway[0].transit_gateway_id : null
  route_table_ids     = module.vpc.private_route_table_ids

  static_routes_only = length(var.vpn.static_routes) > 0
  static_routes      = var.vpn.static_routes

  # IKEv2 with strong ciphers only (module defaults: AES-256/128, SHA-2, DH 14+).
  enable_monitoring = true
  alarm_actions     = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --------------------------------------------
# Client VPN  (stack includes "client-vpn")
# --------------------------------------------
resource "aws_security_group" "client_vpn" {
  count       = local.has.client_vpn ? 1 : 0
  name        = "${local.prefix}-client-vpn"
  description = "Client VPN endpoint ENIs"
  vpc_id      = module.vpc.vpc_id
  tags        = merge(local.tags, { Name = "${local.prefix}-client-vpn" })
}

resource "aws_vpc_security_group_egress_rule" "client_vpn" {
  count             = local.has.client_vpn ? 1 : 0
  security_group_id = aws_security_group.client_vpn[0].id
  description       = "VPN users to the VPC"
  ip_protocol       = "-1"
  cidr_ipv4         = local.vpc_cidr
}

module "client_vpn" {
  source = "./modules/vpn"
  count  = local.has.client_vpn ? 1 : 0

  name_prefix = "${local.prefix}-cvpn"
  vpc_id      = module.vpc.vpc_id

  create_client_vpn           = true
  server_certificate_arn      = var.client_vpn.server_certificate_arn
  client_cidr_block           = var.client_vpn.client_cidr
  split_tunnel                = var.client_vpn.split_tunnel
  authentication_type         = try(var.client_vpn.saml_provider_arn, null) != null ? "federated-authentication" : "certificate-authentication"
  client_root_certificate_arn = try(var.client_vpn.client_root_certificate_arn, null)
  saml_provider_arn           = try(var.client_vpn.saml_provider_arn, null)

  client_vpn_subnet_ids         = module.vpc.private_subnet_ids
  client_vpn_security_group_ids = [aws_security_group.client_vpn[0].id]

  client_vpn_authorization_rules = [{
    target_network_cidr  = local.vpc_cidr
    authorize_all_groups = true
    description          = "VPC access"
  }]

  enable_connection_logging = true
  log_retention_days        = local.s.log_retention
  enable_monitoring         = true
  alarm_actions             = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --------------------------------------------
# VPC peering (one per entry in var.peerings)
# --------------------------------------------
module "vpc_peering" {
  source   = "./modules/vpc_peering"
  for_each = var.peerings

  peering_name         = "${local.prefix}-${each.key}"
  requester_vpc_id     = module.vpc.vpc_id
  requester_cidr_block = local.vpc_cidr
  accepter_vpc_id      = each.value.vpc_id
  accepter_cidr_block  = each.value.cidr

  requester_route_table_ids = module.vpc.private_route_table_ids
  accepter_route_table_ids  = each.value.route_table_ids

  peer_owner_id = each.value.peer_owner_id
  peer_region   = each.value.peer_region
  auto_accept   = each.value.peer_owner_id == null && each.value.peer_region == null

  tags = local.tags
}
