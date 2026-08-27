# Inputs for the bootstrap composition. These currently feed only the AWS provider's
# default_tags (see main.tf) — bootstrap has no resources yet (those arrive in Step
# 3.2). Keeping them as variables instead of literals means every later composition
# that reuses this same tag shape can share the same variable contract.

variable "aws_region" {
  description = <<-EOT
    AWS region the bootstrap resources (state bucket, lock table, KMS key) are created
    in. Deliberately left with no default: the plan calls out the region choice as an
    explicit decision checkpoint in Step 3.2 ("the region choice pins every later
    resource"), so it must be supplied there rather than guessed here.
  EOT
  type        = string
}

variable "project" {
  description = "Short slug identifying this project. Applied as the Project tag on every resource for cost attribution and search."
  type        = string
  default     = "realworld-aws"
}

variable "environment" {
  description = <<-EOT
    Logical environment these resources belong to, applied as the Environment tag.
    Bootstrap manages remote-state infrastructure shared by every env/component
    composition (dev and prod alike), so it is not itself "dev" or "prod" — it
    defaults to "global" rather than picking one env arbitrarily. Per-env
    compositions (terraform/envs/<env>/<component>) override this with their own
    "dev" / "prod" value once they gain a provider block.
  EOT
  type        = string
  default     = "global"
}

variable "owner" {
  description = "Person or team accountable for these resources, applied as the Owner tag. Used for on-call routing and cost accountability."
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Billing cost-center code, applied as the CostCenter tag so spend can be attributed in cost reports."
  type        = string
  default     = "engineering"
}
