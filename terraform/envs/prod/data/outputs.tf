# read via remote state by dev/platform's eks module to scope eso's iam policy
# (yes, dev/platform - the one eks cluster/eso installation serves both envs, adr 0015)
output "app_secret_arn" {
  description = "ARN of the prod/realworld/app secret (JWT signing key)."
  value       = aws_secretsmanager_secret.app.arn
}
