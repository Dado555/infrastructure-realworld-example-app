# Customer-managed KMS key used to encrypt the Terraform state bucket (see
# s3.tf). A CMK (rather than the AWS-managed aws/s3 key) is used so key
# rotation, the key policy, and access auditing are all explicit and owned by
# this composition instead of an implicit account default.
resource "aws_kms_key" "terraform_state" {
  description = "Encrypts the ${local.state_bucket_name} Terraform remote state bucket"

  # Automatic annual key material rotation, required by the plan's security
  # notes for state-encryption keys. AWS handles rotation transparently; the
  # key's ARN/ID never change, so no dependent resource needs updating.
  enable_key_rotation = true

  # 30 days (the maximum) gives the widest window to notice and cancel an
  # accidental deletion before the key — and therefore every encrypted state
  # file it protects — becomes unrecoverable.
  deletion_window_in_days = 30

  # No custom key policy is set: AWS applies its default policy in that case,
  # which grants the account root full IAM-governed access. That is
  # sufficient for a single-account bootstrap; a cross-account or
  # least-privilege policy can be layered on later without recreating the key.
}

# Alias so humans and future backend.hcl files can reference
# "alias/realworld-terraform-state" instead of memorizing a key ARN.
resource "aws_kms_alias" "terraform_state" {
  name          = local.kms_alias_name
  target_key_id = aws_kms_key.terraform_state.key_id
}
