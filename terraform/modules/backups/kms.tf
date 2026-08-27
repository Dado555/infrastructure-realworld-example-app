# dedicated key for the backup vault - per-service cmk pattern, not shared with rds/eks/app-secrets keys
resource "aws_kms_key" "backup" {
  description             = "Encrypts AWS Backup vault for ${var.name_prefix}"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_deletion_window_in_days
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${var.name_prefix}-backup"
  target_key_id = aws_kms_key.backup.key_id
}
