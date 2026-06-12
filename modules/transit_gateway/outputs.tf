output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.main.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.main.arn
}

output "transit_gateway_owner_id" {
  description = "Identifier of the AWS account that owns the Transit Gateway"
  value       = aws_ec2_transit_gateway.main.owner_id
}

output "transit_gateway_association_default_route_table_id" {
  description = "ID of the default association route table"
  value       = aws_ec2_transit_gateway.main.association_default_route_table_id
}

output "transit_gateway_propagation_default_route_table_id" {
  description = "ID of the default propagation route table"
  value       = aws_ec2_transit_gateway.main.propagation_default_route_table_id
}

output "vpc_attachment_ids" {
  description = "Map of VPC attachment names to their IDs"
  value = {
    for k, v in aws_ec2_transit_gateway_vpc_attachment.main : k => v.id
  }
}

output "vpc_attachments" {
  description = "Map of VPC attachment details"
  value = {
    for k, v in aws_ec2_transit_gateway_vpc_attachment.main : k => {
      id                     = v.id
      vpc_id                 = v.vpc_id
      subnet_ids             = v.subnet_ids
      vpc_owner_id           = v.vpc_owner_id
      transit_gateway_id     = v.transit_gateway_id
    }
  }
}

output "transit_gateway_route_table_ids" {
  description = "Map of Transit Gateway route table names to their IDs"
  value = {
    for k, v in aws_ec2_transit_gateway_route_table.main : k => v.id
  }
}

output "transit_gateway_route_tables" {
  description = "Map of Transit Gateway route table details"
  value = {
    for k, v in aws_ec2_transit_gateway_route_table.main : k => {
      id                       = v.id
      default_association_route_table = v.default_association_route_table
      default_propagation_route_table = v.default_propagation_route_table
    }
  }
}

output "ram_resource_share_id" {
  description = "ID of the RAM resource share"
  value       = try(aws_ram_resource_share.tgw[0].id, "")
}

output "ram_resource_share_arn" {
  description = "ARN of the RAM resource share"
  value       = try(aws_ram_resource_share.tgw[0].arn, "")
}

output "transit_gateway_peering_attachment_ids" {
  description = "Map of Transit Gateway peering attachment names to their IDs"
  value = {
    for k, v in aws_ec2_transit_gateway_peering_attachment.main : k => v.id
  }
}

output "flow_logs_log_group_name" {
  description = "Name of the CloudWatch log group for flow logs"
  value       = try(aws_cloudwatch_log_group.tgw_flow_logs[0].name, "")
}

output "flow_logs_role_arn" {
  description = "ARN of the IAM role for flow logs"
  value       = try(aws_iam_role.tgw_flow_logs[0].arn, "")
}

output "bytes_in_alarm_arn" {
  description = "ARN of the bytes in CloudWatch alarm"
  value       = try(aws_cloudwatch_metric_alarm.bytes_in[0].arn, "")
}

output "bytes_out_alarm_arn" {
  description = "ARN of the bytes out CloudWatch alarm"
  value       = try(aws_cloudwatch_metric_alarm.bytes_out[0].arn, "")
}

output "packet_drop_alarm_arn" {
  description = "ARN of the packet drop CloudWatch alarm"
  value       = try(aws_cloudwatch_metric_alarm.packet_drop[0].arn, "")
}
