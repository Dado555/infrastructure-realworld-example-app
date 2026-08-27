# Bootstrap composition: will own the durable, shared infrastructure that every other
# Terraform composition in this repo depends on for remote state — an encrypted S3
# bucket, a DynamoDB lock table, and a KMS key (see docs/terraform.md). It is applied
# with local state first, since nothing can have a remote backend until this exists.
#
# This step (3.1) only scaffolds the provider configuration and default tags below —
# no resources exist yet. The S3 bucket, DynamoDB table, and KMS key are created in
# Step 3.2, the first step in this plan that spends money and creates real AWS
# resources; that step requires its own explicit approval before `terraform apply`.
#
# default_tags applies these five tags to every resource this provider instance
# creates, without each resource block having to repeat them. ManagedBy is hardcoded
# (it is a statement of fact about this provider, not a per-environment choice) while
# the other four are variables so the same file works unchanged across environments
# and accounts.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
    }
  }
}
