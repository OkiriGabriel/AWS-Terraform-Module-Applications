variable "name" {
  description = "Service name (also task family and IAM role prefix)"
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster ARN/ID"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name (for autoscaling resource IDs)"
  type        = string
}

variable "container_name" {
  description = "Container name inside the task"
  type        = string
}

variable "image" {
  description = "Container image"
  type        = string
}

variable "port" {
  description = "Container port"
  type        = number
}

variable "cpu" {
  description = "Task CPU units"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory (MiB)"
  type        = number
  default     = 512
}

variable "cpu_architecture" {
  description = "X86_64 or ARM64"
  type        = string
  default     = "X86_64"
}

variable "desired_count" {
  description = "Initial task count"
  type        = number
  default     = 1
}

variable "min_count" {
  description = "Autoscaling minimum"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Autoscaling maximum"
  type        = number
  default     = 4
}

variable "environment" {
  description = "Plain environment variables"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secret environment variables: NAME => Secrets Manager or SSM parameter ARN"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key protecting referenced secrets (null if AWS-managed)"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Private subnets for tasks"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups for tasks"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ALB target group"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group"
  type        = string
}

variable "capacity_provider" {
  description = "FARGATE or FARGATE_SPOT"
  type        = string
  default     = "FARGATE"
}

variable "enable_exec" {
  description = "Allow `aws ecs execute-command` shells into running containers"
  type        = bool
  default     = false
}

variable "readonly_root_filesystem" {
  description = "Mount the container root filesystem read-only"
  type        = bool
  default     = false
}

variable "efs" {
  description = "EFS mount (uses TLS + IAM through an access point)"
  type = object({
    file_system_id   = string
    file_system_arn  = string
    access_point_id  = string
    access_point_arn = string
    mount_path       = string
  })
  default = null
}

variable "task_policy_json" {
  description = "Extra IAM policy for the application (task role)"
  type        = string
  default     = null
}

variable "health_check_grace_period_seconds" {
  description = "Seconds to ignore failing ALB health checks after a task starts"
  type        = number
  default     = 60
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}

variable "deployed_by_ci" {
  description = "CI owns which task-definition revision runs (Terraform ignores task_definition drift on the service)"
  type        = bool
  default     = false
}
