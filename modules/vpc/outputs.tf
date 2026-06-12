output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ip" {
  description = "The public IP address of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "route_table_ids" {
  description = "List of route table IDs"
  value = concat(
    [aws_route_table.public.id],
    [aws_route_table.private.id]
  )
} 