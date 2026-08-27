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

# reads private-db subnet ids and the rds-sg from the network composition's state
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.network_state_bucket
    key    = var.network_state_key
    region = var.aws_region
  }
}

module "rds" {
  source = "../../../modules/rds"

  name_prefix = "${var.project}-${var.environment}"

  subnet_ids             = data.terraform_remote_state.network.outputs.private_db_subnet_ids
  vpc_security_group_ids = [data.terraform_remote_state.network.outputs.rds_security_group_id]

  engine_version  = var.engine_version
  instance_class  = var.instance_class
  db_name         = var.db_name
  master_username = var.master_username

  backup_window      = var.backup_window
  maintenance_window = var.maintenance_window
}
