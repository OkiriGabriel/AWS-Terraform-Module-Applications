mock_provider "aws" {
  mock_data "aws_organizations_organization" {
    defaults = {
      roots = [{
        id           = "r-abcd"
        arn          = "arn:aws:organizations::111122223333:root/o-example/r-abcd"
        name         = "Root"
        policy_types = [{ type = "SERVICE_CONTROL_POLICY", status = "ENABLED" }]
      }]
    }
  }
}

run "all_packs_fit_in_two_scps" {
  command = apply

  variables {
    organizational_units = ["Security", "Workloads"]
    guardrails           = ["baseline", "deny-iam-users", "region-lock", "require-imdsv2", "require-encryption", "cost-guard"]
    allowed_regions      = ["us-east-1", "eu-west-1"]
  }

  assert {
    condition     = length(aws_organizations_policy.guardrails) == 2
    error_message = "packs should merge into exactly two SCPs"
  }
  assert {
    condition     = alltrue([for s in values(output.policy_sizes) : s <= 5120])
    error_message = "an SCP exceeds the 5,120 character limit"
  }
  assert {
    condition     = length(output.enforced_packs) == 8
    error_message = "baseline should expand into its three packs"
  }
  assert {
    condition     = length(aws_organizations_policy_attachment.guardrails) == 4
    error_message = "2 policies x 2 OUs should give 4 attachments"
  }
}

run "baseline_only_creates_one_scp" {
  command = apply

  variables {
    target_ids = ["r-abcd"]
  }

  assert {
    condition     = keys(aws_organizations_policy.guardrails) == ["identity"]
    error_message = "baseline packs belong to the identity SCP only"
  }
}

run "unknown_pack_rejected" {
  command = plan
  variables {
    guardrails = ["deny-everything"]
  }
  expect_failures = [var.guardrails]
}
