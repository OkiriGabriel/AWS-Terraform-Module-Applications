# Enhanced Observability Stack for boiler-plate
# Distributed tracing, log aggregation, and error tracking

# X-Ray Tracing
resource "aws_xray_sampling_rule" "example" {
  rule_name      = "ApplicationTracing"
  resource_arn   = "*"
  priority       = 9000
  version        = 1
  reservoir_size = 1
  fixed_rate     = 0.1
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_name   = "boiler-plate-*"
  service_type   = "*"
}

# Enhanced CloudWatch Log Groups with Insights
resource "aws_cloudwatch_log_group" "application_insights" {
  name              = "/boiler-plate/${local.environment}/application-insights"
  retention_in_days = 30

  tags = merge(local.tags, {
    Purpose = "Application insights and error tracking"
  })
}

resource "aws_cloudwatch_log_group" "alb_access" {
  name              = "/boiler-plate/${local.environment}/alb-access"
  retention_in_days = 14

  tags = merge(local.tags, {
    Purpose = "ALB access logs"
  })
}

resource "aws_cloudwatch_log_group" "geolocation" {
  name              = "/boiler-plate/${local.environment}/geolocation"
  retention_in_days = 7

  tags = merge(local.tags, {
    Purpose = "Geolocation and region-aware logic logs"
  })
}

# CloudWatch Insights Queries
resource "aws_cloudwatch_query_definition" "error_tracking" {
  count = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name  = "boiler-plate Error Tracking"

  log_group_names = [
    aws_cloudwatch_log_group.frontend[0].name,
    aws_cloudwatch_log_group.backend[0].name,
    aws_cloudwatch_log_group.admin[0].name
  ]

  query_string = <<EOF
fields @timestamp, @message, @logStream
| filter @message like /ERROR/
| stats count(*) by bin(5m)
| sort @timestamp desc
EOF
}

resource "aws_cloudwatch_query_definition" "geolocation_analysis" {
  name = "Geolocation Request Analysis"

  log_group_names = [
    aws_cloudwatch_log_group.geolocation.name
  ]

  query_string = <<EOF
fields @timestamp, city, vendor_count, response_time
| filter ispresent(city)
| stats avg(response_time) by city
| sort avg desc
EOF
}

# Custom Metrics for Business Logic
resource "aws_cloudwatch_log_metric_filter" "vendor_availability" {
  name           = "VendorAvailabilityByCity"
  log_group_name = aws_cloudwatch_log_group.geolocation.name
  pattern        = "[timestamp, request_id, city, vendor_count]"

  metric_transformation {
    name      = "VendorAvailability"
    namespace = "Application/Business"
    value     = "$vendor_count"

    dimensions = {
      City = "$city"
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "api_errors" {
  count          = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name           = "APIErrors"
  log_group_name = aws_cloudwatch_log_group.backend[0].name
  pattern        = "ERROR"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "Application/Application"
    value     = "1"

    dimensions = {
      Service = "Backend"
    }
  }
}