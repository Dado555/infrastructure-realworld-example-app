output "vault_name" {
  description = "Name of the AWS Backup vault."
  value       = aws_backup_vault.this.name
}

output "vault_arn" {
  description = "ARN of the AWS Backup vault."
  value       = aws_backup_vault.this.arn
}

output "plan_id" {
  description = "ID of the AWS Backup plan."
  value       = aws_backup_plan.this.id
}

output "plan_arn" {
  description = "ARN of the AWS Backup plan."
  value       = aws_backup_plan.this.arn
}

output "iam_role_arn" {
  description = "ARN of the IAM role AWS Backup assumes to run backup jobs."
  value       = aws_iam_role.backup.arn
}

output "kms_key_arn" {
  description = "ARN of the dedicated CMK used for backup vault encryption."
  value       = aws_kms_key.backup.arn
}
