variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "versioning" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = false
}

variable "public_read_access" {
  description = "Allow public read access to the bucket"
  type        = bool
  default     = false
}

variable "lifecycle_rules" {
  description = "Lifecycle rules for the bucket"
  type = list(object({
    id     = string
    status = string
    transition = optional(object({
      days          = number
      storage_class = string
    }))
    expiration = optional(object({
      days = number
    }))
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
variable "enforce_tls" {
  description = "Attach a bucket policy that denies any request not made over TLS. Set false only if another resource owns this bucket's policy."
  type        = bool
  default     = true
}

variable "additional_policy_statements" {
  description = "Extra IAM policy statements (as HCL objects) merged into the bucket policy"
  type        = any
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key ARN for SSE-KMS. Null uses SSE-S3 (AES256)."
  type        = string
  default     = null
}
