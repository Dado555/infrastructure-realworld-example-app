# Naming convention for the bootstrap resources, centralized here so the
# convention is documented once instead of inlined at each resource block.
locals {
  # S3 bucket names are globally unique across ALL AWS accounts, not just this
  # one, so a plain "realworld-terraform-state" name would risk colliding with
  # another AWS customer's bucket (the plan calls this out explicitly as a
  # common failure mode). Suffixing with the account ID resolved from
  # data.aws_caller_identity (rather than a hardcoded literal) keeps this
  # composition copy-paste-safe for a future second account without editing
  # source.
  state_bucket_name = "realworld-terraform-state-${data.aws_caller_identity.current.account_id}"

  # DynamoDB table names only need to be unique within one account+region, so
  # no account-ID suffix is needed here.
  lock_table_name = "realworld-terraform-locks"

  # Human-readable alias for the state-encryption CMK (see kms.tf). Referenced
  # by convention from docs/terraform.md and any future backend.hcl files that
  # want to display it rather than the raw key ARN.
  kms_alias_name = "alias/realworld-terraform-state"
}
