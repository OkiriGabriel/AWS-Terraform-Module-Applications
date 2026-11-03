# ============================================
# PLAN-TIME GUARDRAILS
# ============================================
# The module refuses insecure or incomplete combinations before anything is created.
# Each message says exactly what to change.

resource "terraform_data" "guardrails" {
  input = var.profile

  lifecycle {
    precondition {
      condition     = !(local.has.ecs && local.s.require_https && !local.https)
      error_message = "Profile '${var.profile}' requires HTTPS for the load balancer. Set domain = { name = \"app.example.com\", zone_id = \"Z...\" } (or certificate_arn), or use profile = \"starter\"."
    }

    precondition {
      condition     = !local.has.ecs || length(var.services) > 0
      error_message = "stack includes \"ecs\" but services is empty. Define at least one service."
    }

    precondition {
      condition     = length([for k, s in var.services : k if length(s.path_patterns) == 1 && s.path_patterns[0] == "/*" && length(s.host_headers) == 0]) <= 1
      error_message = "Only one service can be the catch-all (path_patterns = [\"/*\"] with no host_headers). Give the others specific path_patterns or host_headers."
    }

    precondition {
      condition     = !contains(var.stack, "vpn") || var.vpn != null
      error_message = "stack includes \"vpn\": set vpn = { customer_gateway_ip = \"<your on-prem public IP>\" }."
    }

    precondition {
      condition     = !contains(var.stack, "client-vpn") || var.client_vpn != null
      error_message = "stack includes \"client-vpn\": set client_vpn = { server_certificate_arn = \"arn:aws:acm:...\", client_root_certificate_arn or saml_provider_arn = ... }."
    }

    precondition {
      condition     = var.client_vpn == null || try(var.client_vpn.client_root_certificate_arn, null) != null || try(var.client_vpn.saml_provider_arn, null) != null
      error_message = "client_vpn needs an authentication method: client_root_certificate_arn (mutual TLS) or saml_provider_arn (SSO)."
    }

    precondition {
      condition     = alltrue([for k, s in var.services : s.efs_mount_path == null || local.has.efs])
      error_message = "A service sets efs_mount_path but \"efs\" is not in stack."
    }

    precondition {
      condition     = var.profile != "regulated" || local.s.kms_cmk
      error_message = "Profile 'regulated' cannot run without customer-managed KMS (overrides.kms_cmk = false is not allowed)."
    }

    precondition {
      condition     = var.profile != "regulated" || var.alert_email != ""
      error_message = "Profile 'regulated' requires alert_email so security findings and alarms reach a human."
    }

    precondition {
      condition     = var.profile != "regulated" || !local.s.ecs_exec
      error_message = "Profile 'regulated' does not allow ECS Exec (interactive shells into containers)."
    }

    precondition {
      condition     = var.profile != "regulated" || !local.has.eks || length(var.eks.public_access_cidrs) == 0
      error_message = "Profile 'regulated' keeps the EKS API private. Remove eks.public_access_cidrs and reach it through client-vpn or transit-gateway."
    }

    precondition {
      condition     = contains(["none", "single", "per_az"], local.s.nat_mode)
      error_message = "overrides.nat_mode must be none, single or per_az."
    }

    precondition {
      condition     = local.s.nat_mode != "none" || !(local.has.ecs || local.has.eks) || local.s.interface_endpoints
      error_message = "nat_mode = none leaves ECS/EKS without a path to pull images. Enable overrides.interface_endpoints = true (or keep a NAT)."
    }
  }
}
