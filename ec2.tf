# boiler-plate Development Environment EC2 Servers
# Instance types come from vars_enviro_dev (default t3.micro for Free Tier compatibility).
# No ALB needed - direct access to each server

# Frontend Development Server (WordPress/WooCommerce)
resource "aws_instance" "frontend_dev" {
  count         = terraform.workspace == "infrastructure" ? 1 : 0
  ami           = try(local.current_env.ec2.frontend.ami_id, local.current_env.ec2.ami_id)
  instance_type = try(local.current_env.ec2.frontend.instance_type, local.current_env.ec2.instance_type)
  key_name      = try(local.current_env.ec2.frontend.key_name, local.current_env.ec2.key_name)
  subnet_id     = module.vpc.public_subnet_ids[0] # boiler-plate-public-a
  # Use ecs-instances SG (SSH + web), not ecs_tasks/container SG (ALB-only ingress — no port 22).
  vpc_security_group_ids = [module.security_groups.ecs_instances_security_group_id]

  associate_public_ip_address = true

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker nginx mysql
    systemctl start docker nginx
    systemctl enable docker nginx
    usermod -a -G docker ec2-user
    
    # Install MySQL locally for development
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS app_dev_db;"
    sudo mysql -e "CREATE USER IF NOT EXISTS 'appuser'@'localhost' IDENTIFIED BY 'devpassword';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON app_dev_db.* TO 'appuser'@'localhost';"
    
    # Setup WordPress dev environment
    echo "boiler-plate Frontend Development Server (WordPress/WooCommerce)" > /var/www/html/index.html
  EOF
  )

  tags = merge(local.tags, {
    Name    = "gabriel-boiler-plate-${local.environment}-frontend-server"
    Purpose = "Development Frontend Server (WordPress)"
    Type    = try(local.current_env.ec2.frontend.instance_type, local.current_env.ec2.instance_type)
  })
}

# Backend Development Server (REST API)
resource "aws_instance" "backend_dev" {
  count                  = terraform.workspace == "infrastructure" ? 1 : 0
  ami                    = try(local.current_env.ec2.backend.ami_id, local.current_env.ec2.ami_id)
  instance_type          = try(local.current_env.ec2.backend.instance_type, local.current_env.ec2.instance_type)
  key_name               = try(local.current_env.ec2.backend.key_name, local.current_env.ec2.key_name)
  subnet_id              = module.vpc.public_subnet_ids[1] # boiler-plate-public-b
  vpc_security_group_ids = [module.security_groups.ecs_instances_security_group_id]

  associate_public_ip_address = true

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker nodejs npm redis
    systemctl start docker redis
    systemctl enable docker redis
    usermod -a -G docker ec2-user
    
    # Install Redis locally for development
    systemctl start redis
    
    # Setup backend development environment
    echo "boiler-plate Backend Development Server (REST API)" > /tmp/backend_status.html
  EOF
  )

  tags = merge(local.tags, {
    Name    = "gabriel-boiler-plate-${local.environment}-backend-server"
    Purpose = "Development Backend Server (REST API)"
    Type    = try(local.current_env.ec2.backend.instance_type, local.current_env.ec2.instance_type)
  })
}
