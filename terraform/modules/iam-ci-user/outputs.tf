output "user_arn" {
  description = "ARN of the IAM user."
  value       = aws_iam_user.this.arn
}

output "access_key_id" {
  description = "Access key ID for CI to use. Not secret."
  value       = aws_iam_access_key.this.id
}

output "secret_access_key" {
  description = "Secret access key for CI to use. Only pull this deliberately, never wire it to a composition output."
  value       = aws_iam_access_key.this.secret
  sensitive   = true
}
