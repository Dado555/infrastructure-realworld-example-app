# step 6.4: daily aws backup plan, selecting any resource tagged Backup=true - currently
# just the rds instance (tagged in the rds module, step 6.1). phase 9's prometheus pvc
# volume will be picked up automatically once that volume is tagged, no change needed here
module "backups" {
  source = "../../../modules/backups"

  name_prefix = "${var.project}-${var.environment}"

  daily_delete_after_days = var.backup_daily_retention_days
}
