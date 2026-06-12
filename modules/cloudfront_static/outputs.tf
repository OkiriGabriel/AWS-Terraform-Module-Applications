output "distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = aws_cloudfront_distribution.this.arn
}

output "domain_name" {
  description = "CloudFront domain name (HTTPS URL host for static assets)."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "hosted_zone_id" {
  description = "Route53 hosted zone ID for CloudFront alias records."
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "origin_access_control_id" {
  description = "Origin Access Control ID attached to the S3 origin."
  value       = aws_cloudfront_origin_access_control.this.id
}
