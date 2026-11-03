# Cheapest useful stack: one public web service on Fargate Spot, no domain needed.
# terraform init && terraform apply, then open the `url` in the summary output.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.70.0, < 6.0.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "platform" {
  # In your own repo: source = "git::https://github.com/OkiriGabriel/AWS-Terraform-Module-Applications.git?ref=v1.0.0"
  source = "../../"

  name        = "demo"
  environment = "dev"
  profile     = "starter"
  stack       = ["ecs"]
}

output "summary" {
  value = module.platform.summary
}
