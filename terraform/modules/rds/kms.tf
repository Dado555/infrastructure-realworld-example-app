# dedicated key for rds storage encryption - per-service cmk pattern, not shared with eks's key
resource "aws_kms_key" "rds" {
  description             = "Encrypts RDS storage for ${var.name_prefix}-db"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_deletion_window_in_days
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}
