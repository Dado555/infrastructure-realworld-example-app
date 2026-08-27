variable "aws_region" {
  description = "AWS region these resources are created in."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Identifier for the project. Applied as the Project tag and used in resource naming."
  type        = string
  default     = "realworld-aws"
}

variable "environment" {
  description = "Logical environment tag. This composition is account-level, not per-env, hence 'shared'."
  type        = string
  default     = "shared"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "CostCenter tag, so spend can be attributed in cost reports."
  type        = string
  default     = "engineering"
}

variable "github_owner" {
  description = "GitHub org/user that owns the three repos CI runs out of."
  type        = string
  default     = "Dado555"
}

variable "backend_repo" {
  description = "Backend repo name (owner/repo, minus owner)."
  type        = string
  default     = "spring-boot-realworld-example-app"
}

variable "frontend_repo" {
  description = "Frontend repo name (owner/repo, minus owner)."
  type        = string
  default     = "angular-realworld-example-app"
}

variable "infra_repo" {
  description = "Infra repo name (owner/repo, minus owner)."
  type        = string
  default     = "infrastructure-realworld-example-app"
}

variable "state_bucket_name" {
  description = "Name of the Terraform remote-state S3 bucket, from the bootstrap composition."
  type        = string
  default     = "realworld-terraform-state-262786914511"
}

variable "lock_table_name" {
  description = "Name of the Terraform state-lock DynamoDB table, from the bootstrap composition."
  type        = string
  default     = "realworld-terraform-locks"
}

variable "ecr_max_image_count" {
  description = "Number of most-recent images each ECR repo retains."
  type        = number
  default     = 20
}

# Naming convention the gha-infra-apply IAM allowance is scoped to - workload roles created by
# later compositions (EKS, RDS, etc.) are expected to be named "<workload_role_prefix>-*", kept
# distinct from this composition's own "gha-*" CI role names.
variable "workload_role_prefix" {
  description = "Prefix used to scope gha-infra-apply's IAM management permissions to workload roles, excluding the gha-* CI roles themselves."
  type        = string
  default     = "realworld-aws"
}
