# ============================================
# EDGE: ALB, TLS CERTIFICATE, DNS, WAF  (created when "ecs" is in stack)
# ============================================

locals {
  services = local.has.ecs ? var.services : {}

  # Routing: specific paths/hosts get rules in key order; a "/*"-only service becomes the catch-all.
  # NOTE: compare elements, not `== ["/*"]` (a list never equals a tuple literal in Terraform).
  is_catch_all       = { for k, s in local.services : k => length(s.path_patterns) == 1 && s.path_patterns[0] == "/*" && length(s.host_headers) == 0 }
  catch_all_services = [for k, c in local.is_catch_all : k if c]
  default_service    = length(local.catch_all_services) > 0 ? local.catch_all_services[0] : null
  routed_services    = [for k in sort(keys(local.services)) : k if !local.is_catch_all[k]]
}

# --------------------------------------------
# Certificate (issued + DNS-validated when domain.zone_id is given)
# --------------------------------------------
resource "aws_acm_certificate" "alb" {
  count             = local.has.ecs && local.issue_certificate ? 1 : 0
  domain_name       = var.domain.name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

resource "aws_route53_record" "cert_validation" {
  # Keyed by the (known) domain name so plans never depend on values ACM only returns after creation.
  for_each = local.has.ecs && local.issue_certificate ? toset([var.domain.name]) : toset([])

  zone_id         = var.domain.zone_id
  name            = one([for o in aws_acm_certificate.alb[0].domain_validation_options : o.resource_record_name if o.domain_name == each.key])
  type            = one([for o in aws_acm_certificate.alb[0].domain_validation_options : o.resource_record_type if o.domain_name == each.key])
  records         = [one([for o in aws_acm_certificate.alb[0].domain_validation_options : o.resource_record_value if o.domain_name == each.key])]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "alb" {
  count                   = local.has.ecs && local.issue_certificate ? 1 : 0
  certificate_arn         = aws_acm_certificate.alb[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_route53_record" "alb" {
  count   = local.has.ecs && try(var.domain.zone_id, null) != null ? 1 : 0
  zone_id = var.domain.zone_id
  name    = var.domain.name
  type    = "A"

  alias {
    name                   = aws_lb.main[0].dns_name
    zone_id                = aws_lb.main[0].zone_id
    evaluate_target_health = true
  }
}

# --------------------------------------------
# Load balancer
# --------------------------------------------
resource "aws_lb" "main" {
  count              = local.has.ecs ? 1 : 0
  name               = "${local.prefix}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [module.security_groups.alb_security_group_id]
  subnets            = module.vpc.public_subnet_ids

  enable_deletion_protection = local.s.alb_deletion_protect
  drop_invalid_header_fields = true
  idle_timeout               = 60

  tags = merge(local.tags, { Name = "${local.prefix}-alb" })
}

resource "aws_lb_target_group" "service" {
  for_each = local.services

  name                 = substr("${local.prefix}-${each.key}", 0, 32)
  port                 = each.value.port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = each.value.health_check_path
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(local.tags, { Service = each.key })
}

# HTTP: redirect to HTTPS when a certificate exists, otherwise serve (starter without a domain).
resource "aws_lb_listener" "http" {
  count             = local.has.ecs ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.https ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.https ? [] : [1]
    content {
      type             = local.default_service != null ? "forward" : "fixed-response"
      target_group_arn = local.default_service != null ? aws_lb_target_group.service[local.default_service].arn : null

      dynamic "fixed_response" {
        for_each = local.default_service == null ? [1] : []
        content {
          content_type = "text/plain"
          message_body = "Not found"
          status_code  = "404"
        }
      }
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = local.has.ecs && local.https ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = local.default_service != null ? "forward" : "fixed-response"
    target_group_arn = local.default_service != null ? aws_lb_target_group.service[local.default_service].arn : null

    dynamic "fixed_response" {
      for_each = local.default_service == null ? [1] : []
      content {
        content_type = "text/plain"
        message_body = "Not found"
        status_code  = "404"
      }
    }
  }
}

resource "aws_lb_listener_rule" "service" {
  for_each = { for i, k in local.routed_services : k => i }

  listener_arn = local.https ? aws_lb_listener.https[0].arn : aws_lb_listener.http[0].arn
  priority     = 100 + each.value * 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[each.key].arn
  }

  dynamic "condition" {
    for_each = !(length(local.services[each.key].path_patterns) == 1 && local.services[each.key].path_patterns[0] == "/*") ? [1] : []
    content {
      path_pattern {
        values = local.services[each.key].path_patterns
      }
    }
  }

  dynamic "condition" {
    for_each = length(local.services[each.key].host_headers) > 0 ? [1] : []
    content {
      host_header {
        values = local.services[each.key].host_headers
      }
    }
  }
}

# --------------------------------------------
# WAF
# --------------------------------------------
locals {
  waf_enabled = local.has.ecs && local.s.waf

  waf_managed_rule_groups = [
    "AWSManagedRulesAmazonIpReputationList",
    "AWSManagedRulesCommonRuleSet",
    "AWSManagedRulesKnownBadInputsRuleSet",
    "AWSManagedRulesSQLiRuleSet",
  ]
}

resource "aws_wafv2_web_acl" "main" {
  count = local.waf_enabled ? 1 : 0
  name  = "${local.prefix}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit-per-ip"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = local.s.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-per-ip"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = length(local.s.waf_blocked_countries) > 0 ? [1] : []
    content {
      name     = "geo-block"
      priority = 2

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = local.s.waf_blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "geo-block"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = { for i, n in local.waf_managed_rule_groups : n => i }
    content {
      name     = rule.key
      priority = 10 + rule.value

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = local.tags
}

resource "aws_wafv2_web_acl_association" "alb" {
  count        = local.waf_enabled ? 1 : 0
  resource_arn = aws_lb.main[0].arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}

# WAF log group names must start with "aws-waf-logs-".
resource "aws_cloudwatch_log_group" "waf" {
  count             = local.waf_enabled ? 1 : 0
  name              = "aws-waf-logs-${local.prefix}"
  retention_in_days = local.s.log_retention
  kms_key_id        = local.kms_key_arn
  tags              = local.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count                   = local.waf_enabled ? 1 : 0
  resource_arn            = aws_wafv2_web_acl.main[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}
