variable "aws_region" {
  description = "AWS region these resources are created in."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Identifier for the project. Applied as the Project tag and used in resource naming."
  type        = string
  default     = "realworld-aws"
}

variable "environment" {
  description = "Logical environment these resources belong to, applied as the Environment tag."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "CostCenter tag, so spend can be attributed in cost reports."
  type        = string
  default     = "engineering"
}

variable "network_state_bucket" {
  description = "S3 bucket holding the network composition's remote state."
  type        = string
  default     = "realworld-terraform-state-262786914511"
}

variable "network_state_key" {
  description = "State key for the network composition, read via terraform_remote_state."
  type        = string
  default     = "dev/network/terraform.tfstate"
}

# 14.24: latest 14.x patch RDS actually offers as of this writing (confirmed via
# describe-db-engine-versions), matches the major version Step 1.3 validated against Flyway
variable "engine_version" {
  description = "PostgreSQL engine version, pinned to a specific RDS-available patch."
  type        = string
  default     = "14.24"
}

variable "instance_class" {
  description = "RDS instance class. db.t4g.micro for dev per §3.8."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Initial database name. Must match what the app expects (.env.example: DB_URL=.../realworld)."
  type        = string
  default     = "realworld"
}

variable "master_username" {
  description = "Master username for RDS-managed credentials. Not secret - the generated password lives in Secrets Manager."
  type        = string
  default     = "realworld_admin"
}

# low-traffic UTC hour, well clear of the maintenance window below
variable "backup_window" {
  description = "Preferred UTC window for automated backups."
  type        = string
  default     = "03:00-04:00"
}

# weekly, different day/window than backups so the two never overlap
variable "maintenance_window" {
  description = "Preferred UTC window for maintenance."
  type        = string
  default     = "mon:05:00-mon:06:00"
}

# dev value per plan §3.8; a future prod caller of the backups module would pass 30
variable "backup_daily_retention_days" {
  description = "Days to retain AWS Backup daily recovery points."
  type        = number
  default     = 7
}

# step 9.6: user-provided, not terraform-generated (unlike the jwt/grafana secrets) - no
# default, must be supplied at apply time via TF_VAR_slack_webhook_url so the raw value never
# appears in any command's own visible argument text, let alone a committed file.
variable "slack_webhook_url" {
  description = "Slack incoming webhook URL for Alertmanager notifications."
  type        = string
  sensitive   = true
}
