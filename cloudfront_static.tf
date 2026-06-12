# # Static assets CDN — same child module for dev and prod (bucket comes from current workspace env).

# module "cloudfront_static" {
#   source = "./modules/cloudfront_static"

#   environment  = local.environment
#   project_name = local.project_name
#   tags         = local.tags

#   s3_bucket_id                   = module.s3_static.bucket_id
#   s3_bucket_arn                  = module.s3_static.bucket_arn
#   s3_bucket_regional_domain_name = module.s3_static.bucket_regional_domain_name
# }
