variable "name_prefix" {
  description = "Prefix applied to resource names, e.g. realworld-aws-dev."
  type        = string
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period before the dedicated backup-vault CMK is actually deleted, after a destroy."
  type        = number
  default     = 30
}

# 04:00 utc - starts right after rds's own 03:00-04:00 automated backup window (step 6.1)
# closes, and well clear of the monday 05:00-06:00 maintenance window
variable "daily_schedule" {
  description = "Cron expression (UTC) for the daily backup rule."
  type        = string
  default     = "cron(0 4 * * ? *)"
}

variable "daily_delete_after_days" {
  description = "Days to retain daily recovery points. 7 for dev, 30 for prod per plan §3.8."
  type        = number
  default     = 7
}

variable "enable_monthly_rule" {
  description = "Adds a second rule with long-term monthly retention. False in dev; a future prod caller sets this true."
  type        = bool
  default     = false
}

variable "monthly_schedule" {
  description = "Cron expression (UTC) for the monthly rule. Only used when enable_monthly_rule is true."
  type        = string
  default     = "cron(0 4 1 * ? *)"
}

variable "monthly_delete_after_days" {
  description = "Days to retain monthly recovery points. Only used when enable_monthly_rule is true. 365 (1 year) for prod per plan §3.8."
  type        = number
  default     = 365
}

variable "selection_tag_key" {
  description = "Tag key used to select resources into this backup plan."
  type        = string
  default     = "Backup"
}

variable "selection_tag_value" {
  description = "Tag value used to select resources into this backup plan."
  type        = string
  default     = "true"
}
