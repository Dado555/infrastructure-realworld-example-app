# Pins the Terraform CLI and provider versions this composition is validated against.
# Pinning here (rather than leaving these unconstrained) is what keeps `terraform init`
# reproducible across a laptop and CI: every machine resolves the same CLI minor line
# and the same provider major line, so a provider upgrade is a deliberate edit to this
# file, never a silent surprise picked up by the next `terraform init`.
#
# required_version is pinned to the 1.16.x patch line to match the CLI actually
# installed and verified in this environment (`terraform -version` -> 1.16.0).
# hashicorp/aws is pinned to the 5.x major line (`~> 5.0`), the current stable major
# version of the provider as of this writing; `~>` allows patch and minor upgrades
# within 5.x but blocks an accidental jump to a future breaking major version.
terraform {
  required_version = "~> 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
