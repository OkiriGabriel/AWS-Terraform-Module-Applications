# S3 Buckets Configuration for boiler-plate
# Media bucket for product images, vendor assets, user uploads
module "s3_media" {
  source = "./s3"

  bucket_name = local.current_env.s3.buckets.media.name
  environment = local.environment
  versioning  = local.current_env.s3.buckets.media.versioning

  lifecycle_rules = local.current_env.s3.buckets.media.lifecycle_rules

  # Private bucket with Cloudflare CDN via presigned URLs
  public_read_access = false

  tags = merge(local.tags, {
    Purpose = "Media Storage"
    Type    = "User Generated Content"
  })
}

# Static assets bucket for CSS, JS, fonts, icons
module "s3_static" {
  source = "./s3"

  bucket_name = local.current_env.s3.buckets.static.name
  environment = local.environment
  versioning  = local.current_env.s3.buckets.static.versioning

  lifecycle_rules = local.current_env.s3.buckets.static.lifecycle_rules

  # Private bucket with Cloudflare CDN
  public_read_access = false

  tags = merge(local.tags, {
    Purpose = "Static Assets"
    Type    = "Website Resources"
  })
}

# Backups bucket for database backups, code archives
module "s3_backups" {
  source = "./s3"

  bucket_name = local.current_env.s3.buckets.backups.name
  environment = local.environment
  versioning  = local.current_env.s3.buckets.backups.versioning

  lifecycle_rules = local.current_env.s3.buckets.backups.lifecycle_rules

  # Private bucket, automated backups only
  public_read_access = false

  tags = merge(local.tags, {
    Purpose = "Backup Storage"
    Type    = "Automated Backups"
  })
}

# Configuration bucket for environment configuration files
module "s3_configs" {
  source = "./s3"

  bucket_name = local.current_env.s3.buckets.configs.name
  environment = local.environment
  versioning  = local.current_env.s3.buckets.configs.versioning

  lifecycle_rules = local.current_env.s3.buckets.configs.lifecycle_rules

  # Private bucket, application access only
  public_read_access = false

  tags = merge(local.tags, {
    Purpose = "Configuration Storage"
    Type    = "Environment Configs"
  })
}