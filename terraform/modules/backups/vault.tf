resource "aws_backup_vault" "this" {
  name        = "${var.name_prefix}-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn
}
