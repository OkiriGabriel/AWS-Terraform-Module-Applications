# Load balancer: public 80/443 in, only VPC-internal traffic out.
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Application Load Balancer"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_vpc_security_group_ingress_rule" "alb" {
  for_each = { for pair in setproduct([80, 443], var.alb_ingress_cidrs) : "${pair[0]}-${pair[1]}" => pair }

  security_group_id = aws_security_group.alb.id
  description       = "HTTP(S) from ${each.value[1]}"
  ip_protocol       = "tcp"
  from_port         = each.value[0]
  to_port           = each.value[0]
  cidr_ipv4         = each.value[1]
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  for_each = toset([for p in var.service_ports : tostring(p)])

  security_group_id            = aws_security_group.alb.id
  description                  = "To service tasks on ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.key)
  to_port                      = tonumber(each.key)
  referenced_security_group_id = aws_security_group.tasks.id
}

# Service tasks / pods: only the ALB may connect, on each service's port.
resource "aws_security_group" "tasks" {
  name        = "${var.name}-tasks"
  description = "ECS tasks and EKS workloads"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-tasks" })
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  for_each = toset([for p in var.service_ports : tostring(p)])

  security_group_id            = aws_security_group.tasks.id
  description                  = "From ALB on ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.key)
  to_port                      = tonumber(each.key)
  referenced_security_group_id = aws_security_group.alb.id
}

# Outbound: tasks call AWS APIs, data stores and third parties (through NAT or VPC endpoints).
resource "aws_vpc_security_group_egress_rule" "tasks_all" {
  security_group_id = aws_security_group.tasks.id
  description       = "Outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
