# ACM Certificate for HTTPS (Production only)

data "aws_acm_certificate" "main" {
  count       = terraform.workspace == "infrastructure-prod" ? 1 : 0
  domain      = "boiler-plate.com"
  statuses    = ["ISSUED"]
  most_recent = true
}