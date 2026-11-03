# S3 Bucket
resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name

  tags = merge(var.tags, {
    Name        = var.bucket_name
    Environment = var.environment
  })
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = var.versioning ? "Enabled" : "Suspended"
  }
}

# S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

# Disable ACLs entirely; the bucket owner owns every object.
resource "aws_s3_bucket_ownership_controls" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = !var.public_read_access
  block_public_policy     = !var.public_read_access
  ignore_public_acls      = !var.public_read_access
  restrict_public_buckets = !var.public_read_access
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "bucket" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.status

      # Add filter to satisfy AWS provider requirements
      filter {
        prefix = try(rule.value.prefix, "")
      }

      dynamic "transition" {
        for_each = rule.value.transition != null ? [rule.value.transition] : []
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration != null ? [rule.value.expiration] : []
        content {
          days = expiration.value.days
        }
      }
    }
  }
}

# Bucket policy: deny non-TLS requests, plus any caller-supplied statements.
# A bucket can only have one policy, so callers that need extra grants (AWS Config, CloudTrail, ...)
# pass them in via var.additional_policy_statements instead of creating their own aws_s3_bucket_policy.
resource "aws_s3_bucket_policy" "this" {
  count  = var.enforce_tls || length(var.additional_policy_statements) > 0 ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      var.enforce_tls ? [
        {
          Sid       = "DenyInsecureTransport"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:*"
          Resource  = [aws_s3_bucket.bucket.arn, "${aws_s3_bucket.bucket.arn}/*"]
          Condition = {
            Bool = { "aws:SecureTransport" = "false" }
          }
        }
      ] : [],
      var.additional_policy_statements
    )
  })

  depends_on = [aws_s3_bucket_public_access_block.bucket]
}
