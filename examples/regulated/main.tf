# Everything on: 3 AZs, customer-managed KMS, private AWS endpoints, VPN to the office, Client VPN for
# engineers, Transit Gateway for future VPCs, EKS for batch, 7-year audit trail, vault-locked backups.

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
  source = "../../"

  name        = "fintech"
  environment = "prod"
  profile     = "regulated"
  stack       = ["ecs", "eks", "rds", "redis", "efs", "vpn", "client-vpn", "transit-gateway"]

  domain = {
    name            = "secure.example.com"
    certificate_arn = "arn:aws:acm:us-east-1:111122223333:certificate/00000000-0000-0000-0000-000000000000"
  }

  services = {
    portal = {
      port           = 8443
      cpu            = 1024
      memory         = 2048
      desired_count  = 3
      efs_mount_path = "/data"
    }
  }

  database = {
    engine = "postgres"
    name   = "ledger"
  }

  vpn = {
    customer_gateway_ip = "198.51.100.10"
    bgp_asn             = 65010
  }

  client_vpn = {
    server_certificate_arn = "arn:aws:acm:us-east-1:111122223333:certificate/11111111-1111-1111-1111-111111111111"
    saml_provider_arn      = "arn:aws:iam::111122223333:saml-provider/okta"
  }

  transit_gateway = {
    routes = ["10.0.0.0/8", "192.168.0.0/16"]
  }

  alert_email = "security@example.com"
}

output "summary" {
  value = module.platform.summary
}
