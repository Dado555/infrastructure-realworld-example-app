# Customer-managed KMS key used to encrypt the Terraform state bucket
resource "aws_kms_key" "terraform_state" {
  description = "Encrypts the ${local.state_bucket_name} Terraform remote state bucket"

  # Automatic key rotation
  enable_key_rotation = true

  # Notice and cancel an accidental deletion before the key becomes unrecoverable
  deletion_window_in_days = 30
}

# Alias for referencing key
resource "aws_kms_alias" "terraform_state" {
  name          = local.kms_alias_name
  target_key_id = aws_kms_key.terraform_state.key_id
}
