variable "environment" {
  description = "Environment name (e.g. dev, prod) — used in resource names and tags."
  type        = string
}

variable "project_name" {
  description = "Short project identifier for naming."
  type        = string
}

variable "tags" {
  description = "Common tags merged into CloudFront resources."
  type        = map(string)
  default     = {}
}

variable "s3_bucket_id" {
  description = "Static assets S3 bucket name (id)."
  type        = string
}

variable "s3_bucket_arn" {
  description = "Static assets S3 bucket ARN."
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "S3 bucket regional domain for REST API origin (required for OAC)."
  type        = string
}

variable "price_class" {
  description = "CloudFront price class (e.g. PriceClass_100)."
  type        = string
  default     = "PriceClass_100"
}

variable "distribution_comment" {
  description = "Optional comment on the distribution; default is derived from project and environment."
  type        = string
  default     = null
}
