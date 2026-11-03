output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private route table IDs (one per AZ)"
  value       = aws_route_table.private[*].id
}

output "nat_public_ips" {
  description = "NAT gateway public IPs (allow-list these at third parties)"
  value       = aws_eip.nat[*].public_ip
}

output "flow_log_group_name" {
  description = "Flow log CloudWatch log group"
  value       = aws_cloudwatch_log_group.flow.name
}
