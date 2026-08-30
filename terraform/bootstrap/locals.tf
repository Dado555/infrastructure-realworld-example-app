locals {
  state_bucket_name = "realworld-terraform-state-${data.aws_caller_identity.current.account_id}"

  lock_table_name = "realworld-terraform-locks"

  kms_alias_name = "alias/realworld-terraform-state"
}
