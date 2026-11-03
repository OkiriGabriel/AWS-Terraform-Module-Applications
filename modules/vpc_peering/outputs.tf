output "peering_connection_id" {
  description = "The ID of the VPC peering connection"
  value       = aws_vpc_peering_connection.main.id
}

output "peering_connection_status" {
  description = "The status of the VPC peering connection"
  value       = aws_vpc_peering_connection.main.accept_status
}

output "requester_vpc_id" {
  description = "The ID of the requester VPC"
  value       = aws_vpc_peering_connection.main.vpc_id
}

output "accepter_vpc_id" {
  description = "The ID of the accepter VPC"
  value       = aws_vpc_peering_connection.main.peer_vpc_id
}

output "requester_owner_id" {
  description = "The AWS account ID of the owner of the requester VPC"
  value       = try(aws_vpc_peering_connection.main.tags["RequesterAccountId"], null)
}

output "accepter_owner_id" {
  description = "The AWS account ID of the owner of the accepter VPC"
  value       = aws_vpc_peering_connection.main.peer_owner_id
}

output "requester_region" {
  description = "The region of the requester VPC"
  value       = try(aws_vpc_peering_connection.main.tags["RequesterRegion"], null)
}

output "accepter_region" {
  description = "The region of the accepter VPC"
  value       = aws_vpc_peering_connection.main.peer_region
}

output "peering_connection_arn" {
  description = "The ARN of the VPC peering connection"
  value       = try("arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:vpc-peering-connection/${aws_vpc_peering_connection.main.id}", null)
}

output "requester_routes" {
  description = "List of route IDs created in the requester VPC"
  value       = aws_route.requester_to_accepter[*].id
}

output "accepter_routes" {
  description = "List of route IDs created in the accepter VPC"
  value       = aws_route.accepter_to_requester[*].id
}
