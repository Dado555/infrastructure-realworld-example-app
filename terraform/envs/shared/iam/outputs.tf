output "ecr_kms_key_arn" {
  description = "ARN of the dedicated CMK encrypting both ECR repos."
  value       = aws_kms_key.ecr.arn
}

output "ecr_backend_repository_url" {
  description = "Push/pull URL of the realworld-backend ECR repository."
  value       = module.ecr_backend.repository_url
}

output "ecr_frontend_repository_url" {
  description = "Push/pull URL of the realworld-frontend ECR repository."
  value       = module.ecr_frontend.repository_url
}

# Secret access keys are deliberately not surfaced here (only at the module output) so a plain
# `terraform output` can't accidentally dump a credential - retrieving one is a separate, narrow step.

output "gha_backend_ecr_push_user_arn" {
  description = "ARN of the IAM user CI uses to push backend images."
  value       = module.gha_backend_ecr_push.user_arn
}

output "gha_backend_ecr_push_access_key_id" {
  description = "Access key ID CI uses to push backend images. Not secret."
  value       = module.gha_backend_ecr_push.access_key_id
}

output "gha_frontend_ecr_push_user_arn" {
  description = "ARN of the IAM user CI uses to push frontend images."
  value       = module.gha_frontend_ecr_push.user_arn
}

output "gha_frontend_ecr_push_access_key_id" {
  description = "Access key ID CI uses to push frontend images. Not secret."
  value       = module.gha_frontend_ecr_push.access_key_id
}

output "gha_infra_plan_user_arn" {
  description = "ARN of the IAM user CI uses to run terraform plan on infra-repo pull requests."
  value       = module.gha_infra_plan.user_arn
}

output "gha_infra_plan_access_key_id" {
  description = "Access key ID CI uses to run terraform plan on infra-repo pull requests. Not secret."
  value       = module.gha_infra_plan.access_key_id
}

output "gha_infra_apply_user_arn" {
  description = "ARN of the IAM user CI uses to run terraform apply from the infra repo's prod GitHub Environment."
  value       = module.gha_infra_apply.user_arn
}

output "gha_infra_apply_access_key_id" {
  description = "Access key ID CI uses to run terraform apply from the infra repo's prod GitHub Environment. Not secret."
  value       = module.gha_infra_apply.access_key_id
}
