# Transit Gateway Module
# Provides a hub-and-spoke network architecture for connecting multiple VPCs and on-premises networks

# Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
  description                     = var.description
  amazon_side_asn                 = var.amazon_side_asn
  default_route_table_association = var.default_route_table_association
  default_route_table_propagation = var.default_route_table_propagation
  dns_support                     = var.dns_support
  vpn_ecmp_support                = var.vpn_ecmp_support
  auto_accept_shared_attachments  = var.auto_accept_shared_attachments
  transit_gateway_cidr_blocks     = var.transit_gateway_cidr_blocks

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

# VPC Attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  for_each = var.vpc_attachments

  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids

  dns_support                                     = lookup(each.value, "dns_support", var.dns_support)
  ipv6_support                                    = lookup(each.value, "ipv6_support", false)
  appliance_mode_support                          = lookup(each.value, "appliance_mode_support", false)
  transit_gateway_default_route_table_association = lookup(each.value, "transit_gateway_default_route_table_association", var.default_route_table_association)
  transit_gateway_default_route_table_propagation = lookup(each.value, "transit_gateway_default_route_table_propagation", var.default_route_table_propagation)

  tags = merge(
    var.tags,
    lookup(each.value, "tags", {}),
    {
      Name = "${var.name}-${each.key}"
    }
  )
}

# Transit Gateway Route Tables
resource "aws_ec2_transit_gateway_route_table" "main" {
  for_each = var.transit_gateway_route_tables

  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = merge(
    var.tags,
    lookup(each.value, "tags", {}),
    {
      Name = "${var.name}-${each.key}"
    }
  )
}

# Transit Gateway Route Table Associations
resource "aws_ec2_transit_gateway_route_table_association" "main" {
  for_each = var.transit_gateway_route_table_associations

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main[each.value.vpc_attachment_id].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main[each.value.transit_gateway_route_table_id].id
}

# Transit Gateway Route Table Propagations
resource "aws_ec2_transit_gateway_route_table_propagation" "main" {
  for_each = var.transit_gateway_route_table_propagations

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main[each.value.vpc_attachment_id].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main[each.value.transit_gateway_route_table_id].id
}

# Static Routes
resource "aws_ec2_transit_gateway_route" "main" {
  for_each = var.transit_gateway_routes

  destination_cidr_block         = each.value.destination_cidr_block
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main[each.value.transit_gateway_route_table_id].id
  transit_gateway_attachment_id  = lookup(each.value, "transit_gateway_attachment_id", null) != null ? aws_ec2_transit_gateway_vpc_attachment.main[each.value.transit_gateway_attachment_id].id : null
  blackhole                      = lookup(each.value, "blackhole", false)
}

# VPC Route Table Routes to Transit Gateway
resource "aws_route" "to_tgw" {
  for_each = var.vpc_route_table_routes

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.destination_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.main]
}

# Resource Access Manager (RAM) Share for Cross-Account Access
resource "aws_ram_resource_share" "tgw" {
  count                     = var.enable_resource_sharing ? 1 : 0
  name                      = "${var.name}-tgw-share"
  allow_external_principals = var.allow_external_principals

  tags = var.tags
}

resource "aws_ram_resource_association" "tgw" {
  count              = var.enable_resource_sharing ? 1 : 0
  resource_arn       = aws_ec2_transit_gateway.main.arn
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}

resource "aws_ram_principal_association" "tgw" {
  count              = var.enable_resource_sharing ? length(var.ram_principals) : 0
  principal          = var.ram_principals[count.index]
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}

# Transit Gateway Peering Attachment (for cross-region connectivity)
resource "aws_ec2_transit_gateway_peering_attachment" "main" {
  for_each = var.transit_gateway_peering_attachments

  transit_gateway_id      = aws_ec2_transit_gateway.main.id
  peer_transit_gateway_id = each.value.peer_transit_gateway_id
  peer_region             = each.value.peer_region
  peer_account_id         = lookup(each.value, "peer_account_id", data.aws_caller_identity.current.account_id)

  tags = merge(
    var.tags,
    lookup(each.value, "tags", {}),
    {
      Name = "${var.name}-peering-${each.key}"
    }
  )
}

# Transit Gateway Peering Attachment Accepter (for receiving end)
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "main" {
  for_each = var.transit_gateway_peering_accepters

  transit_gateway_attachment_id = each.value.transit_gateway_attachment_id

  tags = merge(
    var.tags,
    lookup(each.value, "tags", {}),
    {
      Name = "${var.name}-peering-accepter-${each.key}"
    }
  )
}

# CloudWatch Log Group for Flow Logs (if VPC attachments have flow logs enabled)
resource "aws_cloudwatch_log_group" "tgw_flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/transitgateway/${var.name}"
  retention_in_days = var.flow_logs_retention_days

  tags = var.tags
}

# Flow Logs for Transit Gateway
resource "aws_flow_log" "tgw" {
  count                = var.enable_flow_logs ? 1 : 0
  traffic_type         = var.flow_logs_traffic_type
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.tgw_flow_logs[0].arn
  iam_role_arn         = aws_iam_role.tgw_flow_logs[0].arn
  transit_gateway_id   = aws_ec2_transit_gateway.main.id

  tags = var.tags
}

# IAM Role for Flow Logs
resource "aws_iam_role" "tgw_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.name}-tgw-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "tgw_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.name}-tgw-flow-logs-policy"
  role  = aws_iam_role.tgw_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Alarms for Transit Gateway
resource "aws_cloudwatch_metric_alarm" "bytes_in" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.name}-tgw-bytes-in-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BytesIn"
  namespace           = "AWS/TransitGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = var.bytes_in_threshold
  alarm_description   = "Transit Gateway bytes in exceeds threshold"

  dimensions = {
    TransitGateway = aws_ec2_transit_gateway.main.id
  }

  alarm_actions = var.alarm_actions

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "bytes_out" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.name}-tgw-bytes-out-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BytesOut"
  namespace           = "AWS/TransitGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = var.bytes_out_threshold
  alarm_description   = "Transit Gateway bytes out exceeds threshold"

  dimensions = {
    TransitGateway = aws_ec2_transit_gateway.main.id
  }

  alarm_actions = var.alarm_actions

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "packet_drop" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.name}-tgw-packet-drop"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "PacketDropCountBlackhole"
  namespace           = "AWS/TransitGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = var.packet_drop_threshold
  alarm_description   = "Transit Gateway packet drops detected"

  dimensions = {
    TransitGateway = aws_ec2_transit_gateway.main.id
  }

  alarm_actions = var.alarm_actions

  tags = var.tags
}

data "aws_caller_identity" "current" {}
