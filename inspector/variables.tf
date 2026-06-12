variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "inspector"
}

variable "resource_types" {
  description = "Types of resources to scan (EC2, ECR, LAMBDA, LAMBDA_CODE)"
  type        = list(string)
  default     = ["EC2", "ECR", "LAMBDA"]

  validation {
    condition = alltrue([
      for rt in var.resource_types : contains(["EC2", "ECR", "LAMBDA", "LAMBDA_CODE"], rt)
    ])
    error_message = "Resource types must be one of: EC2, ECR, LAMBDA, LAMBDA_CODE."
  }
}

variable "enable_notifications" {
  description = "Enable SNS notifications for findings"
  type        = bool
  default     = true
}

variable "notification_emails" {
  description = "List of email addresses to receive Inspector notifications"
  type        = list(string)
  default     = []
}

variable "severity_filter" {
  description = "Filter findings by severity (CRITICAL, HIGH, MEDIUM, LOW, INFORMATIONAL)"
  type        = list(string)
  default     = ["CRITICAL", "HIGH"]

  validation {
    condition = alltrue([
      for s in var.severity_filter : contains(["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFORMATIONAL"], s)
    ])
    error_message = "Severity must be one of: CRITICAL, HIGH, MEDIUM, LOW, INFORMATIONAL."
  }
}

variable "enable_cloudwatch_logs" {
  description = "Send findings to CloudWatch Logs"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 90
}

variable "enable_report_export" {
  description = "Enable export of assessment reports to S3"
  type        = bool
  default     = true
}

variable "report_retention_days" {
  description = "Number of days to retain reports in S3 (0 = never expire)"
  type        = number
  default     = 365
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting reports and findings"
  type        = string
  default     = null
}

variable "enable_automated_remediation" {
  description = "Enable automated remediation for certain findings"
  type        = bool
  default     = false
}

variable "enable_alarms" {
  description = "Enable CloudWatch alarms for findings"
  type        = bool
  default     = true
}

variable "high_severity_threshold" {
  description = "Threshold for high severity findings alarm"
  type        = number
  default     = 1
}

variable "delegated_admin_account_id" {
  description = "Account ID to designate as delegated admin for Inspector (for multi-account setup)"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
