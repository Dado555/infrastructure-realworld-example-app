resource "aws_backup_plan" "this" {
  name = "${var.name_prefix}-backup-plan"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.daily_schedule

    lifecycle {
      delete_after = var.daily_delete_after_days
    }
  }

  # off by default (dev) - a future prod caller sets enable_monthly_rule = true for the
  # 1-year long-term retention rule required by plan §3.8, without touching this module
  dynamic "rule" {
    for_each = var.enable_monthly_rule ? [1] : []

    content {
      rule_name         = "monthly"
      target_vault_name = aws_backup_vault.this.name
      schedule          = var.monthly_schedule

      lifecycle {
        delete_after = var.monthly_delete_after_days
      }
    }
  }
}
