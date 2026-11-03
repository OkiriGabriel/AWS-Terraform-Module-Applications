# Apply ONCE from the AWS Organizations management account.
# Creates OUs and attaches SCP guardrails; workload accounts then use the root module.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.70.0, < 6.0.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "organization" {
  source = "../../modules/organization"
  # In your own repo: source = "OkiriGabriel/platform/aws//modules/organization" and version = "~> 1.0"

  name                 = "acme"
  organizational_units = ["Security", "Workloads", "Sandbox"]

  guardrails = [
    "baseline", # deny-leave-org + deny-root-user + protect-security-services
    "deny-iam-users",
    "region-lock",
    "require-imdsv2",
    "require-encryption",
    "cost-guard",
  ]

  allowed_regions = ["us-east-1", "us-west-2"]

  # Break-glass + the role your pipelines use to run the workload module (it manages GuardDuty/Config/etc.).
  exempt_principal_arns = [
    "arn:aws:iam::*:role/OrganizationAccountAccessRole",
    "arn:aws:iam::*:role/terraform-deploy",
  ]

  security_account_id = "222233334444"
}

output "guardrails" {
  value = {
    packs   = module.organization.enforced_packs
    sizes   = module.organization.policy_sizes
    targets = module.organization.attached_targets
  }
}
