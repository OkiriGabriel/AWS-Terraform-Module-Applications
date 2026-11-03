# ============================================
# ALERTS, ALARMS, DASHBOARD
# ============================================
# Alarms and the dashboard are generated from what is actually deployed; nothing to wire by hand.

resource "aws_sns_topic" "alerts" {
  name              = "${local.prefix}-alerts"
  kms_master_key_id = local.kms_key_arn
  tags              = local.tags
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

locals {
  alb_suffix = local.has.ecs ? aws_lb.main[0].arn_suffix : null

  alarms = merge(
    { for k, tg in aws_lb_target_group.service : "${k}-no-healthy-targets" => {
      description = "Service ${k} has no healthy targets behind the load balancer."
      namespace   = "AWS/ApplicationELB"
      metric      = "HealthyHostCount"
      statistic   = "Minimum"
      comparison  = "LessThanThreshold"
      threshold   = 1
      period      = 60
      periods     = 3
      missing     = "breaching"
      dimensions  = { LoadBalancer = local.alb_suffix, TargetGroup = tg.arn_suffix }
    } },
    local.has.ecs ? {
      "alb-5xx" = {
        description = "Load balancer returned more than 10 5xx errors in 5 minutes."
        namespace   = "AWS/ApplicationELB"
        metric      = "HTTPCode_ELB_5XX_Count"
        statistic   = "Sum"
        comparison  = "GreaterThanThreshold"
        threshold   = 10
        period      = 300
        periods     = 1
        missing     = "notBreaching"
        dimensions  = { LoadBalancer = local.alb_suffix }
      }
      "targets-5xx" = {
        description = "Services returned more than 25 5xx responses in 5 minutes."
        namespace   = "AWS/ApplicationELB"
        metric      = "HTTPCode_Target_5XX_Count"
        statistic   = "Sum"
        comparison  = "GreaterThanThreshold"
        threshold   = 25
        period      = 300
        periods     = 1
        missing     = "notBreaching"
        dimensions  = { LoadBalancer = local.alb_suffix }
      }
    } : {},
    local.has.rds ? {
      "rds-cpu" = {
        description = "Database CPU above 80% for 15 minutes."
        namespace   = "AWS/RDS"
        metric      = "CPUUtilization"
        statistic   = "Average"
        comparison  = "GreaterThanThreshold"
        threshold   = 80
        period      = 300
        periods     = 3
        missing     = "notBreaching"
        dimensions  = { DBInstanceIdentifier = module.rds[0].identifier }
      }
      "rds-storage" = {
        description = "Database free storage below 5 GiB."
        namespace   = "AWS/RDS"
        metric      = "FreeStorageSpace"
        statistic   = "Minimum"
        comparison  = "LessThanThreshold"
        threshold   = 5368709120
        period      = 300
        periods     = 1
        missing     = "notBreaching"
        dimensions  = { DBInstanceIdentifier = module.rds[0].identifier }
      }
    } : {},
    local.has.redis ? {
      "redis-cpu" = {
        description = "Redis engine CPU above 80% for 15 minutes."
        namespace   = "AWS/ElastiCache"
        metric      = "EngineCPUUtilization"
        statistic   = "Average"
        comparison  = "GreaterThanThreshold"
        threshold   = 80
        period      = 300
        periods     = 3
        missing     = "notBreaching"
        dimensions  = { ReplicationGroupId = module.redis[0].replication_group_id }
      }
      "redis-memory" = {
        description = "Redis memory usage above 85%."
        namespace   = "AWS/ElastiCache"
        metric      = "DatabaseMemoryUsagePercentage"
        statistic   = "Average"
        comparison  = "GreaterThanThreshold"
        threshold   = 85
        period      = 300
        periods     = 2
        missing     = "notBreaching"
        dimensions  = { ReplicationGroupId = module.redis[0].replication_group_id }
      }
    } : {}
  )
}

resource "aws_cloudwatch_metric_alarm" "platform" {
  for_each = local.alarms

  alarm_name          = "${local.prefix}-${each.key}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  statistic           = each.value.statistic
  comparison_operator = each.value.comparison
  threshold           = each.value.threshold
  period              = each.value.period
  evaluation_periods  = each.value.periods
  treat_missing_data  = each.value.missing
  dimensions          = each.value.dimensions
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --------------------------------------------
# Dashboard: one page for everything in the stack
# --------------------------------------------
locals {
  dash_widgets = concat(
    [for x in [
      {
        type = "metric", width = 12, height = 6
        properties = {
          title  = "Load balancer: requests and errors"
          region = local.region
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_suffix],
            [".", "HTTPCode_Target_5XX_Count", ".", "."],
            [".", "HTTPCode_ELB_5XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
          ]
        }
      },
      {
        type = "metric", width = 12, height = 6
        properties = {
          title   = "Load balancer: latency p95 (s)"
          region  = local.region
          stat    = "p95"
          period  = 60
          metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_suffix]]
        }
      },
      {
        type = "metric", width = 12, height = 6
        properties = {
          title   = "Services: CPU %"
          region  = local.region
          stat    = "Average"
          period  = 60
          metrics = [for k, m in module.ecs_service : ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main[0].name, "ServiceName", m.service_name]]
        }
      },
      {
        type = "metric", width = 12, height = 6
        properties = {
          title   = "Services: memory %"
          region  = local.region
          stat    = "Average"
          period  = 60
          metrics = [for k, m in module.ecs_service : ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main[0].name, "ServiceName", m.service_name]]
        }
      },
    ] : x if local.has.ecs],
    local.has.rds ? [{
      type = "metric", width = 12, height = 6
      properties = {
        title  = "Database"
        region = local.region
        stat   = "Average"
        period = 300
        metrics = [
          ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", module.rds[0].identifier],
          [".", "DatabaseConnections", ".", "."],
        ]
      }
    }] : [],
    local.has.redis ? [{
      type = "metric", width = 12, height = 6
      properties = {
        title  = "Redis"
        region = local.region
        stat   = "Average"
        period = 300
        metrics = [
          ["AWS/ElastiCache", "EngineCPUUtilization", "ReplicationGroupId", module.redis[0].replication_group_id],
          [".", "DatabaseMemoryUsagePercentage", ".", "."],
        ]
      }
    }] : [],
    length(local.alarms) > 0 ? [{
      type = "alarm", width = 24, height = 4
      properties = {
        title  = "Alarms"
        alarms = [for a in aws_cloudwatch_metric_alarm.platform : a.arn]
      }
    }] : []
  )
}

resource "aws_cloudwatch_dashboard" "main" {
  count          = length(local.dash_widgets) > 0 ? 1 : 0
  dashboard_name = local.prefix
  dashboard_body = jsonencode({ widgets = local.dash_widgets })
}
