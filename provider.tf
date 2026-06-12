terraform {
  required_version = ">= 1.0.0"
  cloud {
    organization = "gabriel-boiler-plate"
    workspaces {
      name = "infrastructure"  # or "infrastructure-prod" for production
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Default region for this root module (keep in sync with AZs / AMIs in vars_enviro_*.tf).
provider "aws" {
  region = "us-east-1"
  # access_key = "aws_access_key"
  # secret_key = "aws_secret_key"
}

provider "random" {}

