variable "enable" {
  description = "Enable GuardDuty detector"
  type        = bool
  default     = true
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "guardduty"
}

variable "finding_publishing_frequency" {
  description = "Frequency of notifications about findings (FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS)"
  type        = string
  default     = "FIFTEEN_MINUTES"

  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.finding_publishing_frequency)
    error_message = "Finding publishing frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

variable "enable_s3_protection" {
  description = "Enable S3 protection in GuardDuty"
  type        = bool
  default     = true
}

variable "enable_kubernetes_protection" {
  description = "Enable Kubernetes audit logs monitoring"
  type        = bool
  default     = true
}

variable "enable_malware_protection" {
  description = "Enable malware protection for EC2 instances"
  type        = bool
  default     = true
}

variable "enable_notifications" {
  description = "Enable SNS notifications for findings"
  type        = bool
  default     = true
}

variable "notification_emails" {
  description = "List of email addresses to receive GuardDuty notifications"
  type        = list(string)
  default     = []
}

variable "minimum_severity_level" {
  description = "Minimum severity level for notifications (0-10). Null means all severities"
  type        = number
  default     = 4.0

  validation {
    condition     = var.minimum_severity_level == null || (var.minimum_severity_level >= 0 && var.minimum_severity_level <= 10)
    error_message = "Minimum severity level must be between 0 and 10."
  }
}

variable "enable_findings_export" {
  description = "Enable export of findings to S3"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting findings. If not provided, a new key will be created"
  type        = string
  default     = null
}

variable "auto_archive_low_severity" {
  description = "Automatically archive findings with severity less than 4.0"
  type        = bool
  default     = false
}

variable "threat_intel_set_location" {
  description = "S3 URI of custom threat intelligence set (optional)"
  type        = string
  default     = null
}

variable "threat_intel_set_format" {
  description = "Format of threat intelligence set (TXT, STIX, OTX_CSV, ALIEN_VAULT, PROOF_POINT, FIRE_EYE)"
  type        = string
  default     = "TXT"
}

variable "trusted_ip_list_location" {
  description = "S3 URI of trusted IP list (optional)"
  type        = string
  default     = null
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

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
