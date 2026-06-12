locals {
  vpc_internal_cidr = ["10.0.0.0/16"]

  # Dev (no ALB): open stack ports to the internet on a public IP. Prod: VPC + Grafana/Sonar from ALB only.
  monitoring_ingress_rules = var.use_public_ip ? [
    for p in [22, 3000, 9090, 9115, 9000] : { from = p, to = p, cidr = ["0.0.0.0/0"], sg = null }
    ] : [
    { from = 22, to = 22, cidr = local.vpc_internal_cidr, sg = null },
    { from = 9090, to = 9090, cidr = local.vpc_internal_cidr, sg = null },
    { from = 3000, to = 3000, cidr = null, sg = var.alb_security_group_id },
    { from = 9115, to = 9115, cidr = local.vpc_internal_cidr, sg = null },
    { from = 9000, to = 9000, cidr = null, sg = var.alb_security_group_id },
  ]

  asg_subnet_ids = var.use_public_ip ? var.public_subnet_ids : var.private_subnet_ids
}

# Security Group for Monitoring Server
resource "aws_security_group" "monitoring" {
  name        = "${var.environment}-monitoring-sg"
  description = "Security group for monitoring server (${var.use_public_ip ? "public dev" : "private + ALB"})"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = local.monitoring_ingress_rules
    content {
      description     = ingress.value.sg != null ? "from ALB" : "monitoring access"
      from_port       = ingress.value.from
      to_port         = ingress.value.to
      protocol        = "tcp"
      cidr_blocks     = ingress.value.sg == null ? ingress.value.cidr : null
      security_groups = ingress.value.sg != null && ingress.value.sg != "" ? [ingress.value.sg] : null
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-monitoring-sg"
  })
}

# IAM Role for Monitoring Server
resource "aws_iam_role" "monitoring" {
  name = "${var.environment}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for CloudWatch access
resource "aws_iam_role_policy" "monitoring_cloudwatch" {
  name = "${var.environment}-monitoring-cloudwatch-policy"
  role = aws_iam_role.monitoring.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ecs:ListClusters",
          "ecs:ListServices",
          "ecs:DescribeServices",
          "ecs:ListTasks",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "monitoring" {
  name = "${var.environment}-monitoring-profile"
  role = aws_iam_role.monitoring.name

  tags = var.tags
}

# Launch Template for Monitoring Server
resource "aws_launch_template" "monitoring" {
  name_prefix   = "${var.environment}-monitoring-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  dynamic "network_interfaces" {
    for_each = var.use_public_ip ? [1] : []
    content {
      associate_public_ip_address = true
      device_index                = 0
      security_groups             = [aws_security_group.monitoring.id]
      delete_on_termination       = true
    }
  }

  vpc_security_group_ids = var.use_public_ip ? null : [aws_security_group.monitoring.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.monitoring.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment = var.environment
    services    = var.services
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.environment}-monitoring-server"
      Type = "Monitoring"
    })
  }

  tags = var.tags
}

# Auto Scaling Group for Monitoring Server
resource "aws_autoscaling_group" "monitoring" {
  name                      = "${var.environment}-monitoring-asg"
  vpc_zone_identifier       = local.asg_subnet_ids
  target_group_arns         = []
  health_check_type         = "EC2"
  health_check_grace_period = 300

  min_size         = 1
  max_size         = 1
  desired_capacity = 1

  launch_template {
    id      = aws_launch_template.monitoring.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-monitoring-asg"
    propagate_at_launch = false
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}