locals {
  state_bucket_name = "realworld-terraform-state-${data.aws_caller_identity.current.account_id}"

  # DynamoDB terraform lock table
  lock_table_name = "realworld-terraform-locks"

  # Alias for the CMK
  kms_alias_name = "alias/realworld-terraform-state"
}
