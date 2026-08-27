# Bootstrap composition: owns the durable, shared infrastructure that every other
# Terraform composition in this repo depends on for remote state — an encrypted S3
# bucket, a DynamoDB lock table, and a KMS key (see docs/terraform.md, and kms.tf /
# s3.tf / dynamodb.tf for the resources themselves). It is applied with local state
# first, since nothing can have a remote backend until this exists.
#
# Step 3.1 scaffolded only the provider configuration and default tags below. Step
# 3.2 (this step) adds the actual resources in kms.tf/s3.tf/dynamodb.tf/data.tf/
# locals.tf/outputs.tf — the first resources in this plan that spend money and
# create real AWS infrastructure. Defining them here is not the same as creating
# them: nothing exists in AWS until a human explicitly approves `terraform apply`
# on a reviewed plan; that has not happened yet as of this commit. Once it does,
# Step 3.3 adds the `backend` block here (or in a new backend.tf) to migrate this
# composition itself onto the remote state it just created.
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
