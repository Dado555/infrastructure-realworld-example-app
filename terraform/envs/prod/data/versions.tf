# Pins the Terraform CLI and provider versions this composition is validated against.
# Mirrors terraform/bootstrap/versions.tf so every composition in the repo resolves
# the same CLI minor line and provider major line - see docs/terraform.md for the
# reasoning. No provider block or resources exist in this composition yet; that
# arrives in a later step once this component's real infrastructure is designed.
terraform {
  required_version = "~> 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
