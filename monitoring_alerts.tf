# Independent CloudWatch/SNS alerts (do not rely on the monitoring EC2 stack).
# Addresses monitoring SPOF: alerts still fire if Prometheus/Grafana host is down.

locals {
  prod_workspace = terraform.workspace == "infrastructure-prod"
}

resource "aws_cloudwatch_metric_alarm" "monitoring_asg_unhealthy" {
  count = local.monitoring_enabled ? 1 : 0

  alarm_name          = "${local.environment}-monitoring-asg-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = 300
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Monitoring EC2 ASG has no in-service instances; Grafana/Prometheus may be down."
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = module.monitoring_server[0].autoscaling_group_name
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_frontend_unhealthy" {
  count = local.prod_workspace ? 1 : 0

  alarm_name          = "${local.environment}-alb-frontend-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Frontend target group has unhealthy targets."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main[0].arn_suffix
    TargetGroup  = aws_lb_target_group.frontend[0].arn_suffix
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_frontend_running_tasks_low" {
  count = local.prod_workspace ? 1 : 0

  alarm_name          = "${local.environment}-ecs-frontend-tasks-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Frontend ECS service has fewer than one running task."
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main[0].name
    ServiceName = "${local.environment}-frontend-service"
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_cpu_high" {
  count = local.prod_workspace ? 1 : 0

  alarm_name          = "${local.environment}-redis-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Redis CPU sustained high; session/cache degradation possible."
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    CacheClusterId = "${local.environment}-redis"
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  count = local.prod_workspace ? 1 : 0

  alarm_name          = "${local.environment}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648 # 2 GiB in bytes
  alarm_description   = "RDS free storage below 2 GiB."
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = "${local.environment}-db"
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_backend_running_tasks_low" {
  count = local.prod_workspace ? 1 : 0

  alarm_name          = "${local.environment}-ecs-backend-tasks-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Backend ECS service has fewer than one running task."
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main[0].name
    ServiceName = "${local.environment}-backend-service"
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  count = local.prod_workspace ? 1 : 0

  alarm_name          = "${local.environment}-rds-connections-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 90 # max_connections = 100; warn at 90% capacity
  alarm_description   = "RDS connection count at or above 90 (max_connections=100). Risk of connection pool exhaustion."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = "${local.environment}-db"
  }

  tags = local.tags
}
