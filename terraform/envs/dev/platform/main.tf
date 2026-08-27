# default_tags applies these five tags to every resource this provider creates
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

# Cross-composition read of the network state - VPC/subnet IDs come from here, never hardcoded.
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.network_state_bucket
    key    = var.network_state_key
    region = var.aws_region
  }
}

module "eks" {
  source = "../../../modules/eks"

  name_prefix = "${var.project}-${var.environment}"

  kubernetes_version = var.kubernetes_version

  subnet_ids = data.terraform_remote_state.network.outputs.private_app_subnet_ids

  endpoint_public_access_cidrs = var.eks_endpoint_public_access_cidrs
  cluster_log_retention_days   = var.eks_cluster_log_retention_days
  admin_principal_arn          = var.eks_admin_principal_arn
}
