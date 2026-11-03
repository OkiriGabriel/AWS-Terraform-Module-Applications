variable "name" {
  description = "Prefix for policy and OU names"
  type        = string
  default     = "platform"
}

variable "guardrails" {
  description = <<-EOT
    SCP packs to enforce. "baseline" = deny-leave-org + deny-root-user + protect-security-services.
      deny-leave-org            accounts cannot leave the organization
      deny-root-user            member-account root user can do nothing
      protect-security-services nobody can stop/delete CloudTrail, GuardDuty, Config, Security Hub, Access Analyzer,
                                or turn off EBS default encryption / S3 account public access block
      deny-iam-users            no IAM users or access keys (use SSO / roles)
      region-lock               only var.allowed_regions (global services exempt)
      require-imdsv2            EC2 must use IMDSv2
      require-encryption        EBS volumes, RDS, Aurora and EFS must be created encrypted
      cost-guard                no GPU/metal/huge instances, no RI or Savings Plan purchases
  EOT
  type        = set(string)
  default     = ["baseline"]

  validation {
    condition = alltrue([for g in var.guardrails : contains([
      "baseline", "deny-leave-org", "deny-root-user", "protect-security-services", "deny-iam-users",
      "region-lock", "require-imdsv2", "require-encryption", "cost-guard",
    ], g)])
    error_message = "Unknown guardrail pack. See the variable description for the list."
  }
}

variable "allowed_regions" {
  description = "Regions permitted by region-lock"
  type        = list(string)
  default     = ["us-east-1"]
}

variable "exempt_principal_arns" {
  description = <<-EOT
    Principals the guardrails do not apply to (ARN patterns, wildcards allowed): break-glass roles and the
    role Terraform uses to manage security services. deny-root-user and deny-leave-org apply to everyone.
  EOT
  type        = list(string)
  default = [
    "arn:aws:iam::*:role/OrganizationAccountAccessRole",
    "arn:aws:iam::*:role/AWSControlTowerExecution",
  ]
}

variable "organizational_units" {
  description = "OUs to create under the root, e.g. [\"Security\", \"Workloads\", \"Sandbox\"]"
  type        = list(string)
  default     = []
}

variable "attach_to_created_ous" {
  description = "Attach the guardrails to every OU this module creates"
  type        = bool
  default     = true
}

variable "target_ids" {
  description = "Existing root, OU or account IDs to attach the guardrails to (r-xxxx, ou-xxxx, 123456789012)"
  type        = list(string)
  default     = []
}

variable "security_account_id" {
  description = "Delegate GuardDuty and Security Hub administration to this member account (null = skip)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
