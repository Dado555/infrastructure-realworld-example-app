output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

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

output "gha_backend_ecr_push_role_arn" {
  description = "ARN CI assumes to push backend images."
  value       = module.gha_backend_ecr_push.role_arn
}

output "gha_frontend_ecr_push_role_arn" {
  description = "ARN CI assumes to push frontend images."
  value       = module.gha_frontend_ecr_push.role_arn
}

output "gha_infra_plan_role_arn" {
  description = "ARN CI assumes to run terraform plan on infra-repo pull requests."
  value       = module.gha_infra_plan.role_arn
}

output "gha_infra_apply_role_arn" {
  description = "ARN CI assumes to run terraform apply from the infra repo's prod GitHub Environment."
  value       = module.gha_infra_apply.role_arn
}
