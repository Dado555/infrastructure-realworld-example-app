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

# reads vpc/subnet ids from the network composition's state
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.network_state_bucket
    key    = var.network_state_key
    region = var.aws_region
  }
}

# step 6.3: reads the two secret arns eso needs (app jwt secret + rds managed credential) from the data composition
data "terraform_remote_state" "data" {
  backend = "s3"

  config = {
    bucket = var.data_state_bucket
    key    = var.data_state_key
    region = var.aws_region
  }
}

# adr 0015: prod's app secret lives in its own state (terraform/envs/prod/data),
# but eso runs once in this same cluster and needs to read both
data "terraform_remote_state" "prod_data" {
  backend = "s3"

  config = {
    bucket = var.data_state_bucket
    key    = "prod/data/terraform.tfstate"
    region = var.aws_region
  }
}

module "eks" {
  source = "../../../modules/eks"

  name_prefix = "${var.project}-${var.environment}"
  aws_region  = var.aws_region

  kubernetes_version = var.kubernetes_version

  subnet_ids = data.terraform_remote_state.network.outputs.private_app_subnet_ids

  endpoint_public_access_cidrs     = var.eks_endpoint_public_access_cidrs
  cluster_log_retention_days       = var.eks_cluster_log_retention_days
  observability_log_retention_days = var.eks_observability_log_retention_days
  admin_principal_arn              = var.eks_admin_principal_arn

  node_security_group_id = data.terraform_remote_state.network.outputs.node_security_group_id
  node_instance_type     = var.node_instance_type
  node_desired_size      = var.node_desired_size
  node_min_size          = var.node_min_size
  node_max_size          = var.node_max_size

  app_secret_arn            = data.terraform_remote_state.data.outputs.app_secret_arn
  app_secrets_kms_key_arn   = data.terraform_remote_state.data.outputs.app_secrets_kms_key_arn
  rds_master_secret_arn     = data.terraform_remote_state.data.outputs.master_user_secret_arn
  additional_app_secret_arn = data.terraform_remote_state.prod_data.outputs.app_secret_arn
}

# token for the helm provider - same tf-user creds, no irsa needed (irsa/oidc is scp-blocked here anyway)
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

# wires helm_release resources (argo cd, in the eks module) to the live cluster
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
