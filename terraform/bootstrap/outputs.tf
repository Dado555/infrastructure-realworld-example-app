# Values every later composition's backend.tf/backend.hcl (Step 3.3) needs to
# point at this remote state: bucket name, lock table name, and the KMS key
# used for encryption. Exposed as outputs instead of requiring readers to
# re-derive the naming convention from locals.tf.
output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform remote state for every other composition."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the Terraform remote state bucket."
  value       = aws_s3_bucket.terraform_state.arn
}

output "lock_table_name" {
  description = "Name of the DynamoDB table used for S3 backend state locking."
  value       = aws_dynamodb_table.terraform_locks.name
}

output "kms_key_arn" {
  description = "ARN of the CMK encrypting the state bucket."
  value       = aws_kms_key.terraform_state.arn
}

output "kms_key_alias" {
  description = "Human-readable alias of the state-encryption CMK."
  value       = aws_kms_alias.terraform_state.name
}
