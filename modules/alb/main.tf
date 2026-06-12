# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.environment}-${var.service_name}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = var.tags
}

# Target Group
resource "aws_lb_target_group" "main" {
  name        = "${var.environment}-${var.service_name}-tg"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 60
    matcher             = "200-299"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 30
    unhealthy_threshold = 5
  }

  tags = var.tags
}

# HTTP Listener (Redirects to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  depends_on = [aws_lb_target_group.main]
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  depends_on = [aws_lb_target_group.main]
}

# Wait for 2 minutes before creating auto-scaling
# resource "time_sleep" "wait_2_minutes" {
#   depends_on = [aws_lb.main, aws_lb_target_group.main]
#   create_duration = "2m"
#   triggers = {
#     service_name = var.ecs_service_name
#   }
# }

# Auto Scaling Target (only if ECS service name is provided)
# resource "aws_appautoscaling_target" "ecs_target" {
#   count              = var.ecs_cluster_name != null && var.ecs_service_name != null ? 1 : 0
#   max_capacity       = var.max_capacity
#   min_capacity       = var.min_capacity
#   resource_id        = "service/${var.ecs_cluster_name}/${var.ecs_service_name}"
#   scalable_dimension = "ecs:service:DesiredCount"
#   service_namespace  = "ecs"

#   lifecycle {
#     precondition {
#       condition     = var.ecs_service_name != null
#       error_message = "ECS service name must be provided before creating auto-scaling target"
#     }
#   }
# }

# # Auto Scaling Policy - CPU (only if ECS service name is provided)
# resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
#   count              = var.ecs_cluster_name != null && var.ecs_service_name != null ? 1 : 0
#   name               = "${var.environment}-${var.service_name}-cpu-policy"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
#   scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
#   service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

#   target_tracking_scaling_policy_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ECSServiceAverageCPUUtilization"
#     }
#     target_value = 70.0
#     scale_in_cooldown  = 900  # 15 minutes before scaling down
#     scale_out_cooldown = 60   # 1 minute before scaling up
#     disable_scale_in   = true # Disable automatic scale in
#   }

#   lifecycle {
#     precondition {
#       condition     = var.ecs_service_name != null
#       error_message = "ECS service name must be provided before creating auto-scaling policy"
#     }
#   }
# }

# # Auto Scaling Policy - Memory (only if ECS service name is provided)
# resource "aws_appautoscaling_policy" "ecs_memory_policy" {
#   count              = var.ecs_cluster_name != null && var.ecs_service_name != null ? 1 : 0
#   name               = "${var.environment}-${var.service_name}-memory-policy"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
#   scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
#   service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

#   target_tracking_scaling_policy_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ECSServiceAverageMemoryUtilization"
#     }
#     target_value = 70.0
#     scale_in_cooldown  = 900  # 15 minutes before scaling down
#     scale_out_cooldown = 60   # 1 minute before scaling up
#     disable_scale_in   = true # Disable automatic scale in
#   }

#   lifecycle {
#     precondition {
#       condition     = var.ecs_service_name != null
#       error_message = "ECS service name must be provided before creating auto-scaling policy"
#     }
#   }
# } 