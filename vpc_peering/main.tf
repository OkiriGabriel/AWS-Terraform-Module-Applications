# VPC Peering Module
# Creates VPC peering connections between VPCs

# VPC Peering Connection
resource "aws_vpc_peering_connection" "main" {
  vpc_id        = var.requester_vpc_id
  peer_vpc_id   = var.accepter_vpc_id
  peer_owner_id = var.peer_owner_id != null ? var.peer_owner_id : data.aws_caller_identity.current.account_id
  peer_region   = var.peer_region
  auto_accept   = var.auto_accept && var.peer_region == null

  requester {
    allow_remote_vpc_dns_resolution = var.requester_allow_remote_vpc_dns_resolution
  }

  dynamic "accepter" {
    for_each = var.auto_accept && var.peer_region == null ? [1] : []
    content {
      allow_remote_vpc_dns_resolution = var.accepter_allow_remote_vpc_dns_resolution
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.peering_name != null ? var.peering_name : "${var.requester_vpc_id}-to-${var.accepter_vpc_id}"
      Side = "Requester"
    }
  )
}

# VPC Peering Connection Accepter (for cross-region or cross-account)
resource "aws_vpc_peering_connection_accepter" "peer" {
  count                     = var.auto_accept == false || var.peer_region != null ? 1 : 0
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  auto_accept               = var.auto_accept

  tags = merge(
    var.tags,
    {
      Name = var.peering_name != null ? "${var.peering_name}-accepter" : "${var.requester_vpc_id}-to-${var.accepter_vpc_id}-accepter"
      Side = "Accepter"
    }
  )
}

# Route from Requester to Accepter
resource "aws_route" "requester_to_accepter" {
  count                     = length(var.requester_route_table_ids)
  route_table_id            = var.requester_route_table_ids[count.index]
  destination_cidr_block    = var.accepter_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [
    aws_vpc_peering_connection.main,
    aws_vpc_peering_connection_accepter.peer
  ]
}

# Route from Accepter to Requester
resource "aws_route" "accepter_to_requester" {
  count                     = length(var.accepter_route_table_ids)
  route_table_id            = var.accepter_route_table_ids[count.index]
  destination_cidr_block    = var.requester_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [
    aws_vpc_peering_connection.main,
    aws_vpc_peering_connection_accepter.peer
  ]
}

# Security Group Rules for Peering (optional)
resource "aws_security_group_rule" "requester_ingress" {
  count                    = var.create_security_group_rules ? length(var.requester_security_group_ids) : 0
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  cidr_blocks              = [var.accepter_cidr_block]
  security_group_id        = var.requester_security_group_ids[count.index]
  description              = "Allow all traffic from peered VPC ${var.accepter_vpc_id}"
}

resource "aws_security_group_rule" "accepter_ingress" {
  count                    = var.create_security_group_rules ? length(var.accepter_security_group_ids) : 0
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  cidr_blocks              = [var.requester_cidr_block]
  security_group_id        = var.accepter_security_group_ids[count.index]
  description              = "Allow all traffic from peered VPC ${var.requester_vpc_id}"
}

# CloudWatch Metric Alarm for Peering Connection Status (optional)
resource "aws_cloudwatch_metric_alarm" "peering_status" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.peering_name != null ? var.peering_name : aws_vpc_peering_connection.main.id}-status"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "PeeringConnectionStatus"
  namespace           = "AWS/VPC"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Monitor VPC peering connection status"
  treat_missing_data  = "breaching"

  dimensions = {
    PeeringConnectionId = aws_vpc_peering_connection.main.id
  }

  alarm_actions = var.alarm_actions

  tags = var.tags
}

# VPC Peering Connection Options (for additional configuration)
resource "aws_vpc_peering_connection_options" "requester" {
  count                     = var.configure_peering_options ? 1 : 0
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  requester {
    allow_remote_vpc_dns_resolution  = var.requester_allow_remote_vpc_dns_resolution
  }

  depends_on = [
    aws_vpc_peering_connection.main,
    aws_vpc_peering_connection_accepter.peer
  ]
}

resource "aws_vpc_peering_connection_options" "accepter" {
  count                     = var.configure_peering_options && (var.auto_accept || var.peer_region == null) ? 1 : 0
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  accepter {
    allow_remote_vpc_dns_resolution  = var.accepter_allow_remote_vpc_dns_resolution
  }

  depends_on = [
    aws_vpc_peering_connection.main,
    aws_vpc_peering_connection_accepter.peer
  ]
}

data "aws_caller_identity" "current" {}
