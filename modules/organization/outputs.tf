output "policy_ids" {
  description = "SCP IDs by group (identity, controls)"
  value       = { for k, p in aws_organizations_policy.guardrails : k => p.id }
}

output "policy_sizes" {
  description = "Characters used per SCP (limit 5,120)"
  value       = { for k, v in local.policies : k => length(v) }
}

output "enforced_packs" {
  description = "Guardrail packs in force after expanding \"baseline\""
  value       = sort(tolist(local.packs))
}

output "organizational_unit_ids" {
  description = "Created OU IDs by name"
  value       = { for k, ou in aws_organizations_organizational_unit.this : k => ou.id }
}

output "attached_targets" {
  description = "Roots/OUs/accounts the guardrails are attached to"
  value       = local.targets
}
