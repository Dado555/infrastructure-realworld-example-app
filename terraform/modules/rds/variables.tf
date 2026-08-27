variable "name_prefix" {
  description = "Prefix applied to resource names/tags, e.g. realworld-dev."
  type        = string
}

variable "subnet_ids" {
  description = "Private-db subnet IDs the DB subnet group spans, one per AZ."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) == 2
    error_message = "Exactly 2 subnet IDs are required (one per AZ)."
  }
}

variable "vpc_security_group_ids" {
  description = "Security group IDs attached to the instance (the rds-sg from the network composition)."
  type        = list(string)
}

variable "engine_version" {
  description = "PostgreSQL engine version, pinned to a specific RDS-available patch."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "EBS storage type backing the instance."
  type        = string
  default     = "gp3"
}

variable "db_name" {
  description = "Initial database name created on the instance."
  type        = string
  default     = "realworld"
}

variable "master_username" {
  description = "Master username. Not postgres/admin by convention - not secret, just avoids the reserved defaults."
  type        = string
  default     = "realworld_admin"
}

variable "multi_az" {
  description = "Whether to run a standby in a second AZ. False for dev (§3.8), true for prod."
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Whether the instance gets a public IP. Always false - this DB is reachable only from inside the VPC."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days of automated backups to retain."
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred UTC window for automated backups, e.g. 03:00-04:00."
  type        = string
}

variable "maintenance_window" {
  description = "Preferred UTC window for maintenance, e.g. mon:05:00-mon:06:00. Must not overlap backup_window."
  type        = string
}

variable "deletion_protection" {
  description = "Blocks deletion via the API/console when true. False in dev so teardown works, true in prod."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skips the final snapshot on destroy. True in dev for easy teardown, false in prod."
  type        = bool
  default     = true
}

variable "performance_insights_enabled" {
  description = "Enables Performance Insights (free tier retention by default)."
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention in days. 7 is the free-tier value."
  type        = number
  default     = 7
}

variable "enabled_cloudwatch_logs_exports" {
  description = "Log types exported to CloudWatch. Valid for postgres: postgresql, upgrade, iam-db-auth-error."
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period before the dedicated CMK is actually deleted, after a destroy."
  type        = number
  default     = 30
}
