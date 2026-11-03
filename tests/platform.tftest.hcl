# Runs the whole module against a mocked AWS provider: no credentials, no cost, ~seconds.
#   terraform init && terraform test

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012", arn = "arn:aws:iam::123456789012:root", user_id = "AIDA" }
  }
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
  mock_data "aws_availability_zones" {
    defaults = { names = ["us-east-1a", "us-east-1b", "us-east-1c"] }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:us-east-1:123456789012:mock" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:mock" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/mock" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::mock-bucket" }
  }
  mock_resource "aws_ecs_cluster" {
    defaults = { arn = "arn:aws:ecs:us-east-1:123456789012:cluster/mock" }
  }
  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/mock"
      domain_validation_options = [{
        domain_name           = "app.example.com"
        resource_record_name  = "_abc.app.example.com."
        resource_record_type  = "CNAME"
        resource_record_value = "_def.acm-validations.aws."
      }]
    }
  }
  mock_resource "aws_efs_file_system" {
    defaults = { arn = "arn:aws:elasticfilesystem:us-east-1:123456789012:file-system/fs-mock" }
  }
  mock_resource "aws_efs_access_point" {
    defaults = { arn = "arn:aws:elasticfilesystem:us-east-1:123456789012:access-point/fsap-mock" }
  }
  mock_resource "aws_wafv2_web_acl" {
    defaults = { arn = "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/mock/abc" }
  }
  mock_resource "aws_lb_listener" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/test/abc/def" }
  }
  mock_resource "aws_backup_vault" {
    defaults = { arn = "arn:aws:backup:us-east-1:123456789012:backup-vault:mock" }
  }
  mock_resource "aws_cloudfront_distribution" {
    defaults = { arn = "arn:aws:cloudfront::123456789012:distribution/MOCK" }
  }
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" }
  }
  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:us-east-1:123456789012:rule/mock" }
  }
  mock_resource "aws_ec2_transit_gateway" {
    defaults = { arn = "arn:aws:ec2:us-east-1:123456789012:transit-gateway/tgw-mock" }
  }
  mock_resource "aws_eks_cluster" {
    defaults = {
      arn                   = "arn:aws:eks:us-east-1:123456789012:cluster/mock"
      endpoint              = "https://MOCK.gr7.us-east-1.eks.amazonaws.com"
      certificate_authority = [{ data = "bW9jaw==" }]
      identity              = [{ oidc = [{ issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/MOCK" }] }]
    }
  }
  mock_resource "aws_lambda_function" {
    defaults = { arn = "arn:aws:lambda:us-east-1:123456789012:function:mock" }
  }
  mock_resource "aws_elasticache_replication_group" {
    defaults = { arn = "arn:aws:elasticache:us-east-1:123456789012:replicationgroup:mock" }
  }
  mock_resource "aws_cloudtrail" {
    defaults = { arn = "arn:aws:cloudtrail:us-east-1:123456789012:trail/mock" }
  }
  mock_resource "aws_ecs_service" {
    defaults = { arn = "arn:aws:ecs:us-east-1:123456789012:service/mock/mock" }
  }
  mock_resource "aws_ecs_task_definition" {
    defaults = { arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/mock:1" }
  }
  mock_resource "aws_iam_instance_profile" {
    defaults = { arn = "arn:aws:iam::123456789012:instance-profile/mock" }
  }
  mock_resource "aws_ec2_client_vpn_endpoint" {
    defaults = { arn = "arn:aws:ec2:us-east-1:123456789012:client-vpn-endpoint/cvpn-endpoint-mock" }
  }
  mock_resource "aws_accessanalyzer_analyzer" {
    defaults = { arn = "arn:aws:access-analyzer:us-east-1:123456789012:analyzer/mock" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock/abc", arn_suffix = "targetgroup/mock/abc" }
  }
  mock_resource "aws_ecr_repository" {
    defaults = { arn = "arn:aws:ecr:us-east-1:123456789012:repository/mock", repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/mock" }
  }
  mock_resource "aws_lb" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/test/abc"
      arn_suffix = "app/test/abc"
      dns_name   = "test-123.us-east-1.elb.amazonaws.com"
      zone_id    = "Z35SXDOTRQ7X7K"
    }
  }
  mock_resource "aws_db_instance" {
    defaults = {
      address            = "db.internal"
      port               = 5432
      endpoint           = "db.internal:5432"
      master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds-AbCdEf", kms_key_id = "", secret_status = "active" }]
    }
  }
  mock_resource "aws_secretsmanager_secret" {
    defaults = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis-AbCdEf" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000" }
  }
}

mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = { certificates = [{ sha1_fingerprint = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280" }] }
  }
}

# ---------------------------------------------------------------- happy paths

run "starter_is_cheap_and_works_without_a_domain" {
  command = apply

  variables {
    name    = "demo"
    profile = "starter"
    stack   = ["ecs"]
  }

  assert {
    condition     = startswith(output.summary.url, "http://")
    error_message = "starter without a domain should serve plain HTTP"
  }
  assert {
    condition     = length(aws_lb_listener.https) == 0 && length(aws_wafv2_web_acl.main) == 0
    error_message = "starter should not create HTTPS listener or WAF"
  }
  assert {
    condition     = output.summary.estimated_monthly_usd.by_component.nat_gateways == 33
    error_message = "starter should run exactly one NAT gateway"
  }
  assert {
    condition     = output.settings.ecs_capacity == "FARGATE_SPOT"
    error_message = "starter should use Fargate Spot"
  }
  assert {
    condition     = length(module.guardduty) == 1 && length(aws_cloudtrail.main) == 1 && length(aws_cloudwatch_metric_alarm.cis) == 0
    error_message = "starter keeps GuardDuty + CloudTrail but skips CIS alarms"
  }
}

run "production_wires_https_waf_data_and_routing" {
  command = apply

  variables {
    name    = "acme"
    profile = "production"
    stack   = ["ecs", "rds", "redis"]
    domain  = { name = "app.example.com", zone_id = "Z0123456789" }
    services = {
      web = { port = 3000 }
      api = { port = 8080, path_patterns = ["/api/*"] }
    }
    buckets     = { uploads = {} }
    alert_email = "oncall@example.com"
  }

  assert {
    condition     = length(aws_lb_listener.https) == 1 && length(aws_acm_certificate.alb) == 1 && length(aws_route53_record.alb) == 1
    error_message = "production with a hosted zone should issue a cert, add HTTPS and a DNS alias"
  }
  assert {
    condition     = length(aws_wafv2_web_acl.main) == 1 && length(aws_wafv2_web_acl_logging_configuration.main) == 1
    error_message = "production should enable WAF with logging"
  }
  assert {
    condition     = length(aws_lb_listener_rule.service) == 1 && aws_lb_listener_rule.service["api"].priority == 100
    error_message = "api should get a path rule; web is the catch-all default"
  }
  assert {
    condition     = output.settings.rds_multi_az && output.settings.nat_mode == "per_az"
    error_message = "production should run Multi-AZ RDS and a NAT per AZ"
  }
  assert {
    condition     = length(aws_cloudwatch_metric_alarm.cis) == 15 && length(aws_securityhub_standards_subscription.main) == 2
    error_message = "production should enable 15 CIS alarms and 2 Security Hub standards"
  }
  assert {
    condition     = output.buckets.uploads == "acme-prod-uploads-123456789012"
    error_message = "bucket naming changed"
  }
  assert {
    condition     = length(aws_backup_plan.main) == 1 && length(aws_backup_vault_lock_configuration.main) == 0
    error_message = "production should back up without vault lock"
  }
}

run "regulated_turns_everything_on" {
  command = apply

  variables {
    name        = "fintech"
    profile     = "regulated"
    stack       = ["ecs", "eks", "rds", "redis", "efs", "vpn", "client-vpn", "transit-gateway"]
    domain      = { name = "secure.example.com", certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc" }
    services    = { portal = { port = 8443, efs_mount_path = "/data" } }
    vpn         = { customer_gateway_ip = "198.51.100.10" }
    client_vpn  = { server_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/srv", saml_provider_arn = "arn:aws:iam::123456789012:saml-provider/okta" }
    alert_email = "security@example.com"
  }

  assert {
    condition     = length(aws_kms_key.platform) == 1 && output.kms_key_arn != null
    error_message = "regulated must create the platform CMK"
  }
  assert {
    condition     = length(output.vpc.private_subnet_ids) == 3
    error_message = "regulated should span 3 AZs"
  }
  assert {
    condition     = length(aws_backup_vault_lock_configuration.main) == 1
    error_message = "regulated should lock the backup vault"
  }
  assert {
    condition     = aws_ecr_repository.service["portal"].image_tag_mutability == "IMMUTABLE"
    error_message = "regulated should use immutable image tags"
  }
  assert {
    condition     = length(module.site_to_site_vpn) == 1 && length(module.client_vpn) == 1 && length(module.transit_gateway) == 1
    error_message = "connectivity components missing"
  }
  assert {
    condition     = output.summary.estimated_monthly_usd.total > 1000
    error_message = "regulated estimate looks too low; pricing table may be broken"
  }
}

run "account_baseline_off_skips_singletons" {
  command = apply

  variables {
    name             = "shared"
    profile          = "starter"
    account_baseline = false
  }

  assert {
    condition     = length(module.guardduty) == 0 && length(aws_cloudtrail.main) == 0 && length(aws_ebs_encryption_by_default.main) == 0
    error_message = "account_baseline = false must not manage account singletons"
  }
}

run "github_repo_enables_oidc_and_ci_deploys" {
  command = apply

  variables {
    name              = "demo"
    profile           = "starter"
    github_repository = "acme/app"
  }

  assert {
    condition     = output.github_deploy_role_arn != null && length(module.ecs_service["web"].service_name) > 0
    error_message = "github_repository should create the OIDC deploy role"
  }
  assert {
    condition     = jsondecode(aws_iam_role.github_deploy[0].assume_role_policy).Statement[0].Condition.StringLike["token.actions.githubusercontent.com:sub"] == ["repo:acme/app:ref:refs/heads/main"]
    error_message = "OIDC trust must default to the main branch only"
  }
}

run "overrides_win_over_profile" {
  command = plan

  variables {
    name      = "demo"
    profile   = "starter"
    overrides = { nat_mode = "per_az", waf = true }
  }

  assert {
    condition     = output.settings.nat_mode == "per_az" && output.settings.waf == true
    error_message = "overrides should replace profile values"
  }
}

# ---------------------------------------------------------------- guardrails refuse bad input

run "production_requires_https" {
  command = plan
  variables {
    name    = "acme"
    profile = "production"
  }
  expect_failures = [terraform_data.guardrails]
}

run "vpn_requires_details" {
  command = plan
  variables {
    name    = "acme"
    profile = "starter"
    stack   = ["ecs", "vpn"]
  }
  expect_failures = [terraform_data.guardrails]
}

run "regulated_requires_alert_email" {
  command = plan
  variables {
    name    = "acme"
    profile = "regulated"
    domain  = { name = "x.example.com", certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc" }
  }
  expect_failures = [terraform_data.guardrails]
}

run "regulated_cannot_disable_kms" {
  command = plan
  variables {
    name        = "acme"
    profile     = "regulated"
    domain      = { name = "x.example.com", certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc" }
    alert_email = "a@example.com"
    overrides   = { kms_cmk = false }
  }
  expect_failures = [terraform_data.guardrails]
}

run "only_one_catch_all_service" {
  command = plan
  variables {
    name     = "acme"
    profile  = "starter"
    services = { a = {}, b = {} }
  }
  expect_failures = [terraform_data.guardrails]
}

run "unknown_stack_component_rejected" {
  command = plan
  variables {
    name  = "acme"
    stack = ["ecs", "lambda"]
  }
  expect_failures = [var.stack]
}
