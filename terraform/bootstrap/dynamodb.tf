# Lock table for the S3 backend's state-locking mechanism (wired up in Step
# 3.3's backend.hcl files via the `dynamodb_table` setting). Prevents two
# concurrent `terraform apply` runs from writing the same state file at once.
resource "aws_dynamodb_table" "terraform_locks" {
  name = local.lock_table_name

  # Locking traffic is bursty (near-zero most of the time, brief spikes
  # during applies) and tiny in volume, so pay-per-request avoids paying for
  # provisioned capacity that would sit idle almost all the time.
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
