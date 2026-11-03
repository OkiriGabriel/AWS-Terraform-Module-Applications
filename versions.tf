terraform {
  # 1.5+: check blocks, terraform_data, cross-object preconditions.
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70.0, < 6.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

# This is a reusable module: it declares no provider or backend.
# Configure `provider "aws"` (region, credentials, default_tags) and your backend in the calling configuration.
