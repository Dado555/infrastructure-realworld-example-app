output "db_instance_id" {
  description = "RDS instance identifier."
  value       = module.rds.db_instance_id
}

output "db_instance_endpoint" {
  description = "Connection endpoint, host:port."
  value       = module.rds.db_instance_endpoint
}

output "db_instance_address" {
  description = "Hostname of the RDS instance (no port)."
  value       = module.rds.db_instance_address
}

output "db_name" {
  description = "Initial database name created on the instance."
  value       = module.rds.db_name
}

output "master_username" {
  description = "Master username (not secret)."
  value       = module.rds.master_username
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the AWS-generated master password."
  value       = module.rds.master_user_secret_arn
}

output "rds_kms_key_arn" {
  description = "ARN of the dedicated CMK used for RDS storage encryption."
  value       = module.rds.kms_key_arn
}
