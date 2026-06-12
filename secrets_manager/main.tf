# Generate random password
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Generate random username
resource "random_string" "username" {
  length  = 8
  special = false
  upper   = false
}

# Create the secret
resource "aws_secretsmanager_secret" "secret" {
  name        = var.secret_name
  description = var.secret_description
  tags        = var.tags
}

# Store the secret value
resource "aws_secretsmanager_secret_version" "secret" {
  secret_id = aws_secretsmanager_secret.secret.id
  secret_string = jsonencode({
    username = random_string.username.result
    password = random_password.password.result
    engine   = var.engine
    # host     = var.host
    # port     = var.port
    # dbname   = var.dbname
  })
}

# IAM policy for accessing the secret
resource "aws_iam_policy" "secret_access" {
  name        = "${var.environment}-secret-access"
  description = "Allow access to secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.secret.arn
        ]
      }
    ]
  })
} 