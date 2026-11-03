# ============================================
# GITHUB ACTIONS OIDC DEPLOY ROLE  (github_repository = "owner/repo")
# ============================================
# Short-lived credentials for CI. Scope: push to this stack's ECR repos, register task definitions,
# roll this stack's ECS services, and pass only this stack's task roles. No static access keys.

locals {
  github_oidc         = var.github_repository != ""
  github_subjects     = length(var.github_oidc_subjects) > 0 ? var.github_oidc_subjects : ["repo:${var.github_repository}:ref:refs/heads/main"]
  github_provider_arn = !local.github_oidc ? null : (var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn)
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = local.github_oidc && var.create_github_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
  tags = local.tags
}

data "aws_iam_openid_connect_provider" "github" {
  count = local.github_oidc && !var.create_github_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_deploy" {
  count                = local.github_oidc ? 1 : 0
  name                 = "${local.prefix}-github-deploy"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = local.github_subjects }
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "github_deploy" {
  count = local.github_oidc ? 1 : 0
  name  = "deploy"
  role  = aws_iam_role.github_deploy[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      }],
      length(aws_ecr_repository.service) > 0 ? [{
        Sid    = "EcrPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:CompleteLayerUpload",
          "ecr:DescribeImages", "ecr:DescribeImageScanFindings", "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart",
        ]
        Resource = [for r in aws_ecr_repository.service : r.arn]
      }] : [],
      [for x in [
        {
          Sid      = "EcsTaskDefinitions" # no resource-level permissions for these two
          Effect   = "Allow"
          Action   = ["ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition"]
          Resource = "*"
        },
        {
          Sid      = "EcsDeploy"
          Effect   = "Allow"
          Action   = ["ecs:UpdateService", "ecs:DescribeServices"]
          Resource = "arn:${data.aws_partition.current.partition}:ecs:${local.region}:${local.account_id}:service/${local.prefix}/*"
        },
        {
          Sid       = "PassTaskRoles"
          Effect    = "Allow"
          Action    = "iam:PassRole"
          Resource  = "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:role/${local.prefix}-*"
          Condition = { StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" } }
        }
      ] : x if local.has.ecs],
      local.has.cdn ? [{
        Sid      = "PublishStaticAssets"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "cloudfront:CreateInvalidation"]
        Resource = [module.static_bucket[0].bucket_arn, "${module.static_bucket[0].bucket_arn}/*", module.cdn[0].distribution_arn]
      }] : []
    )
  })
}
