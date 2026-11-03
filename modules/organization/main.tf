# ============================================
# AWS ORGANIZATIONS GUARDRAILS (apply from the management account)
# ============================================

data "aws_organizations_organization" "this" {}

locals {
  root_id = data.aws_organizations_organization.this.roots[0].id

  packs = toset(flatten([
    for g in var.guardrails : g == "baseline" ? ["deny-leave-org", "deny-root-user", "protect-security-services"] : [g]
  ]))

  exempt = { ArnNotLike = { "aws:PrincipalArn" = var.exempt_principal_arns } }

  statements = {
    "deny-leave-org" = [{
      Sid      = "DenyLeaveOrganization"
      Effect   = "Deny"
      Action   = "organizations:LeaveOrganization"
      Resource = "*"
    }]

    "deny-root-user" = [{
      Sid       = "DenyRootUser"
      Effect    = "Deny"
      Action    = "*"
      Resource  = "*"
      Condition = { StringLike = { "aws:PrincipalArn" = "arn:aws:iam::*:root" } }
    }]

    "protect-security-services" = [{
      Sid    = "ProtectSecurityServices"
      Effect = "Deny"
      Action = [
        "cloudtrail:DeleteTrail", "cloudtrail:StopLogging", "cloudtrail:UpdateTrail", "cloudtrail:PutEventSelectors",
        "guardduty:DeleteDetector", "guardduty:DisassociateFromAdministratorAccount", "guardduty:DisassociateFromMasterAccount",
        "guardduty:UpdateDetector", "guardduty:DeleteMembers", "guardduty:StopMonitoringMembers",
        "config:DeleteConfigurationRecorder", "config:StopConfigurationRecorder", "config:DeleteDeliveryChannel",
        "securityhub:DisableSecurityHub", "securityhub:DisassociateFromAdministratorAccount", "securityhub:DeleteMembers",
        "access-analyzer:DeleteAnalyzer",
        "ec2:DisableEbsEncryptionByDefault",
        "s3:PutAccountPublicAccessBlock",
      ]
      Resource  = "*"
      Condition = local.exempt
    }]

    "deny-iam-users" = [{
      Sid       = "DenyIamUsersAndKeys"
      Effect    = "Deny"
      Action    = ["iam:CreateUser", "iam:CreateAccessKey", "iam:CreateLoginProfile"]
      Resource  = "*"
      Condition = local.exempt
    }]

    "region-lock" = [{
      Sid    = "DenyOutsideAllowedRegions"
      Effect = "Deny"
      NotAction = [
        "a4b:*", "access-analyzer:*", "account:*", "acm:*", "aws-marketplace-management:*", "aws-marketplace:*",
        "aws-portal:*", "billing:*", "budgets:*", "ce:*", "chime:*", "cloudfront:*", "config:*", "cur:*",
        "directconnect:*", "ec2:DescribeRegions", "ec2:DescribeTransitGateways", "ec2:DescribeVpnGateways",
        "fms:*", "globalaccelerator:*", "health:*", "iam:*", "importexport:*", "kms:*", "networkmanager:*",
        "organizations:*", "pricing:*", "route53:*", "route53domains:*", "route53-recovery-cluster:*",
        "route53-recovery-control-config:*", "route53-recovery-readiness:*", "s3:GetAccountPublic*",
        "s3:ListAllMyBuckets", "s3:ListMultiRegionAccessPoints", "s3:PutAccountPublic*", "shield:*", "sso:*",
        "sts:*", "support:*", "tag:*", "trustedadvisor:*", "waf-regional:*", "waf:*", "wafv2:*", "wellarchitected:*",
      ]
      Resource = "*"
      Condition = merge(local.exempt, {
        StringNotEquals = { "aws:RequestedRegion" = var.allowed_regions }
      })
    }]

    "require-imdsv2" = [
      {
        Sid       = "RequireImdsV2OnLaunch"
        Effect    = "Deny"
        Action    = "ec2:RunInstances"
        Resource  = "arn:aws:ec2:*:*:instance/*"
        Condition = { StringNotEquals = { "ec2:MetadataHttpTokens" = "required" } }
      },
      {
        Sid       = "DenyImdsV1Downgrade"
        Effect    = "Deny"
        Action    = "ec2:ModifyInstanceMetadataOptions"
        Resource  = "*"
        Condition = merge(local.exempt, { StringNotEquals = { "ec2:Attribute/HttpTokens" = "required" } })
      }
    ]

    "require-encryption" = [
      {
        Sid       = "DenyUnencryptedEbs"
        Effect    = "Deny"
        Action    = "ec2:CreateVolume"
        Resource  = "*"
        Condition = { Bool = { "ec2:Encrypted" = "false" } }
      },
      {
        Sid       = "DenyUnencryptedRds"
        Effect    = "Deny"
        Action    = ["rds:CreateDBInstance", "rds:CreateDBCluster"]
        Resource  = "*"
        Condition = { Bool = { "rds:StorageEncrypted" = "false" } }
      },
      {
        Sid       = "DenyUnencryptedEfs"
        Effect    = "Deny"
        Action    = "elasticfilesystem:CreateFileSystem"
        Resource  = "*"
        Condition = { Bool = { "elasticfilesystem:Encrypted" = "false" } }
      }
    ]

    "cost-guard" = [
      {
        Sid      = "DenyExpensiveInstances"
        Effect   = "Deny"
        Action   = "ec2:RunInstances"
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = merge(local.exempt, {
          StringLike = { "ec2:InstanceType" = ["*.metal*", "p*", "g*", "x*", "u-*", "trn*", "inf*", "dl*", "*.24xlarge", "*.32xlarge", "*.48xlarge"] }
        })
      },
      {
        Sid       = "DenyLongTermCommitments"
        Effect    = "Deny"
        Action    = ["ec2:PurchaseReservedInstancesOffering", "savingsplans:CreateSavingsPlan", "rds:PurchaseReservedDBInstancesOffering"]
        Resource  = "*"
        Condition = local.exempt
      }
    ]
  }

  # AWS allows 5 SCPs per target (one is usually FullAWSAccess), so packs are merged into at most two
  # policies, each checked against the 5,120-character SCP size limit.
  policy_groups = {
    identity = ["deny-leave-org", "deny-root-user", "protect-security-services", "deny-iam-users"]
    controls = ["region-lock", "require-imdsv2", "require-encryption", "cost-guard"]
  }

  policies = {
    for group, members in local.policy_groups : group => jsonencode({
      Version   = "2012-10-17"
      Statement = flatten([for p in members : local.statements[p] if contains(local.packs, p)])
    }) if length(setintersection(toset(members), local.packs)) > 0
  }

  targets = concat(
    var.target_ids,
    var.attach_to_created_ous ? [for ou in aws_organizations_organizational_unit.this : ou.id] : []
  )
}

resource "aws_organizations_organizational_unit" "this" {
  for_each  = toset(var.organizational_units)
  name      = each.key
  parent_id = local.root_id
  tags      = var.tags
}

resource "aws_organizations_policy" "guardrails" {
  for_each    = local.policies
  name        = "${var.name}-guardrails-${each.key}"
  description = "Guardrail packs: ${join(", ", [for p in local.policy_groups[each.key] : p if contains(local.packs, p)])}"
  type        = "SERVICE_CONTROL_POLICY"
  content     = each.value
  tags        = var.tags

  lifecycle {
    precondition {
      condition     = length(each.value) <= 5120
      error_message = "SCP '${each.key}' is ${length(each.value)} characters; AWS allows 5,120. Drop a pack or shorten exempt_principal_arns."
    }
    precondition {
      condition     = contains([for t in data.aws_organizations_organization.this.roots[0].policy_types : t.type if t.status == "ENABLED"], "SERVICE_CONTROL_POLICY")
      error_message = "Service control policies are not enabled in this organization. Enable them: Organizations console > Policies > Service control policies > Enable."
    }
  }
}

resource "aws_organizations_policy_attachment" "guardrails" {
  for_each = {
    for pair in setproduct(keys(local.policies), range(length(local.targets))) :
    "${pair[0]}-${pair[1]}" => { policy = pair[0], target = local.targets[pair[1]] }
  }

  policy_id = aws_organizations_policy.guardrails[each.value.policy].id
  target_id = each.value.target
}

# --------------------------------------------
# Delegated security administration (optional)
# --------------------------------------------
resource "aws_guardduty_organization_admin_account" "this" {
  count            = var.security_account_id != null ? 1 : 0
  admin_account_id = var.security_account_id
}

resource "aws_securityhub_organization_admin_account" "this" {
  count            = var.security_account_id != null ? 1 : 0
  admin_account_id = var.security_account_id
}
