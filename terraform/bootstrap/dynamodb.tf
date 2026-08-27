# Prevents two concurrent terraform apply runs from writing the same state file at once.
resource "aws_dynamodb_table" "terraform_locks" {
  name = local.lock_table_name

  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
