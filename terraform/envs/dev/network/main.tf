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

module "vpc" {
  source = "../../../modules/vpc"

  name_prefix = "${var.project}-${var.environment}"

  vpc_cidr_block = var.vpc_cidr_block

  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs

  flow_log_retention_days = var.flow_log_retention_days

  alb_ingress_cidr  = var.alb_ingress_cidr
  alb_to_node_ports = var.alb_to_node_ports
}
