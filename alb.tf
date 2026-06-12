# boiler-plate Application Load Balancer with Multi-Service Routing
# Routes traffic to Frontend, Backend API, and Admin services based on path

# Main ALB (Production only - dev uses simple EC2)
resource "aws_lb" "main" {
  count              = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name               = "${local.environment}-main-alb"
  internal           = false # Hardcoded since this only runs in prod
  load_balancer_type = "application"
  security_groups    = [module.security_groups.alb_security_group_id]
  subnets            = module.vpc.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(local.tags, {
    Name = "${local.environment}-main-alb"
  })
}

# Target Group for Frontend Service (default route)
resource "aws_lb_target_group" "frontend" {
  count       = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name        = "${local.environment}-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-299"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(local.tags, {
    Name    = "${local.environment}-frontend-tg"
    Service = "Frontend"
  })
}

# Target Group for Backend API Service (/api/*)
resource "aws_lb_target_group" "backend" {
  count       = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name        = "${local.environment}-backend-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-299"
    path                = "/api/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(local.tags, {
    Name    = "${local.environment}-backend-tg"
    Service = "Backend"
  })
}

# Target Group for Admin Service (/admin/*)
resource "aws_lb_target_group" "admin" {
  count       = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name        = "${local.environment}-admin-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-299"
    path                = "/admin/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(local.tags, {
    Name    = "${local.environment}-admin-tg"
    Service = "Admin"
  })
}

# HTTP Listener (Redirects to HTTPS)
resource "aws_lb_listener" "http" {
  count             = terraform.workspace == "infrastructure-prod" ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
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
}

# HTTPS Listener with Path-Based Routing
resource "aws_lb_listener" "https" {
  count             = terraform.workspace == "infrastructure-prod" ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = data.aws_acm_certificate.main[0].arn

  # Default action - Forward to Frontend
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend[0].arn
  }
}

# Listener Rule for Backend API (/api/*)
resource "aws_lb_listener_rule" "backend_api" {
  count        = terraform.workspace == "infrastructure-prod" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend[0].arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# Listener Rule for Admin Dashboard (/admin/*)
resource "aws_lb_listener_rule" "admin" {
  count        = terraform.workspace == "infrastructure-prod" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.admin[0].arn
  }

  condition {
    path_pattern {
      values = ["/admin/*"]
    }
  }
}

# Listener Rule for Grafana (/grafana/*)
resource "aws_lb_listener_rule" "grafana" {
  count        = terraform.workspace == "infrastructure-prod" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 400

  action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.monitoring[0].arn
      }
    }
  }

  condition {
    path_pattern {
      values = ["/grafana/*"]
    }
  }
}

# Listener Rule for SonarQube (/sonar/*)
resource "aws_lb_listener_rule" "sonarqube" {
  count        = terraform.workspace == "infrastructure-prod" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 500

  action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.monitoring[0].arn
      }
    }
  }

  condition {
    path_pattern {
      values = ["/sonar/*"]
    }
  }
}

# Target Group for Monitoring Server (Grafana & SonarQube)
resource "aws_lb_target_group" "monitoring" {
  count       = terraform.workspace == "infrastructure-prod" ? 1 : 0
  name        = "${local.environment}-monitoring-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-299"
    path                = "/grafana/api/health"
    port                = "3000"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(local.tags, {
    Name    = "${local.environment}-monitoring-tg"
    Service = "Monitoring"
  })
}