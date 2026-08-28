# 0002 - IaC tooling: plain Terraform

**Date:** 2026-08-26
**Status:** Accepted

## Context

Infrastructure spans two environments (dev, prod) across roughly five components (network,
EKS, RDS, IAM/OIDC, add-ons). We need a way to manage per-environment, per-component remote
state and provider configuration without excessive duplication or an accident where dev and
prod share state.

## Decision

Use plain Terraform, with one backend configuration file per environment/component pair
(root modules invoked with `-backend-config=<env>-<component>.tfbackend` or equivalent),
rather than a wrapper tool or Terraform workspaces.

## Alternatives considered and rejected

- **Terragrunt.** Gives DRY backend/provider blocks, an explicit dependency graph between
  modules, and `run-all` for multi-module operations. Rejected because the duplication it
  would eliminate here is small: 2 environments x 5 components is roughly a dozen lines of
  backend configuration total. Terragrunt adds a wrapper layer a reviewer must also learn,
  and its indirection (which `terragrunt.hcl` resolves to which `terraform` invocation) makes
  it less obvious which plan is actually running — a real cost for a project this size that
  the DRY savings do not offset.
- **Terraform workspaces (one backend, workspace-per-environment).** Simpler to set up than
  per-component backend files. Rejected because workspaces put dev and prod in the *same*
  state file (different workspace, same backend/state storage), which means a mistargeted
  `terraform apply` or a workspace-selection error can touch the wrong environment's state.
  Separate backend configs per environment give a structural guarantee — dev and prod state
  live in genuinely different storage locations, not just different logical workspaces of one.

## Consequences

- Each environment/component pair needs its own backend config file, so provider/backend
  blocks are duplicated (a small, explicit cost we are accepting).
- No automatic cross-module dependency ordering — module apply order is managed manually
  (documented in the infra repo's run order, not tooled).
- Any engineer familiar with vanilla Terraform can read and operate this repo with no
  additional tool to learn.
- State isolation between dev and prod is structural (separate backends), not just a
  workspace selection that could be gotten wrong.

## Revisit-when

The platform grows to 3+ AWS accounts and 3+ environments, at which point the backend/
provider boilerplate Terragrunt eliminates becomes materially larger, and cross-component
dependency ordering (currently manual) becomes enough manual toil to justify Terragrunt's
dependency graph.
