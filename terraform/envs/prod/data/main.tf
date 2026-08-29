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

# no rds module here - adr 0015: prod deliberately reuses dev's rds instance
# (a new realworld_prod database on it, not a new instance), so this
# composition only provisions the one thing prod genuinely needs its own
# copy of: the jwt signing secret.
