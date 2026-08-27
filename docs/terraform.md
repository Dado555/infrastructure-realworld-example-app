# Terraform layout

This document records the Terraform directory structure and the reasoning behind it,
as of Step 3.1 of the implementation plan (repository skeleton, pinned versions,
default tags — no resources exist yet).

## Directory layout

```
terraform/
  bootstrap/            # State-storage prerequisites: S3 bucket, DynamoDB lock table,
                         # KMS key (created in Step 3.2). Applied with local state
                         # first, since nothing else can have a remote backend until
                         # this exists. One instance, not per-environment.
  modules/               # Reusable modules shared across envs/components. Empty for
                         # now (.gitkeep only) - modules get built starting in later
                         # steps, once there is more than one caller to justify one.
  envs/
    dev/
      network/           # VPC, subnets, routing, NAT/IGW, security groups.
      platform/           # EKS cluster and node groups, IRSA roles, cluster add-ons.
      data/               # RDS instance, parameter/subnet groups, related storage.
    prod/
      network/
      platform/
      data/
```

## Component split: `network` / `platform` / `data`

Each environment (`dev`, `prod`) is split into exactly three components:

- **`network`** — VPC, subnetting, routing, gateways, and any network-level security
  groups. The foundation every other component's resources attach to.
- **`platform`** — the EKS cluster, node groups, IRSA roles, and cluster-level add-ons
  that run workloads. Depends on `network`.
- **`data`** — RDS and any other stateful data infrastructure. Depends on `network`
  (and typically on security groups exposed by it), largely independent of `platform`.

Each component gets its **own Terraform state file** (wired up in Step 3.3), so a
change to `dev/network` can never touch `prod/data`, and a `platform` change can never
accidentally touch `data`'s state even within the same environment. This is the
blast-radius boundary the whole layout is built around.

### Why three components, not four

The plan text that originally sketched this layout listed the split as
`network` / `platform` / `data` / `shared`. This step deliberately implements only
**three** components — `network`, `platform`, `data` — and does **not** create a
`shared` component or directory.

Reasoning:

- No concrete resource has been identified yet that is genuinely cross-cutting at the
  Terraform-state level in a way `network`, `platform`, or `data` can't own. Anything
  that looks "shared" so far (provider version pins, default tags) is handled by
  duplicating a small, deliberately-identical `versions.tf` across every composition
  (see below), not by a shared state file.
- Introducing a `shared` state file before a real resource needs it would mean guessing
  at its contents now and likely reshaping it later — exactly the kind of speculative
  directory this step is meant to avoid ("a valid skeleton that provisions nothing").
- `terraform/bootstrap` already plays the role "infrastructure logically shared across
  every environment" for the one thing that concretely needs it today: remote state
  storage (S3 bucket, DynamoDB lock table, KMS key, Step 3.2). A second `shared`
  component alongside it would overlap in purpose without a distinct resource set to
  justify it.

If a genuinely cross-environment, cross-component resource shows up later (for example
a shared Route 53 hosted zone, or an ECR repository referenced by every environment),
this decision should be revisited explicitly rather than resources being bolted onto
`network`/`platform`/`data` by convenience. Until then: **`network` / `platform` /
`data` only, no `shared`.**

## Version pinning

Every composition (`terraform/bootstrap` and all six `terraform/envs/<env>/<component>`
folders) carries an identical `versions.tf`:

```hcl
terraform {
  required_version = "~> 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- `required_version = "~> 1.16.0"` pins the Terraform CLI to the 1.16.x patch line,
  matching the CLI actually installed and verified in this environment
  (`terraform -version` -> `Terraform v1.16.0`). The `~>` operator with three version
  segments allows only the patch component to float, so `1.16.1`, `1.16.2`, etc. are
  accepted but `1.17.0` is not — an upgrade to a new minor line is a deliberate,
  reviewed edit to this file.
- `version = "~> 5.0"` pins the `hashicorp/aws` provider to the 5.x major line, the
  current stable major version of the provider. The two-segment `~>` constraint allows
  any minor/patch release within `5.x` (so routine provider updates apply without
  editing this file) but blocks an automatic jump to a future `6.x`, which is where a
  provider is most likely to introduce breaking changes.

Keeping this file byte-for-byte identical across every composition is intentional: it
means every environment and component resolves the exact same CLI and provider lines,
so "works on dev" and "works on prod" mean the same toolchain, not just the same code.

## Why `.terraform.lock.hcl` must be committed

Each composition's `.terraform.lock.hcl` (generated the first time `terraform init`
resolves providers against a real registry, which has not happened yet as of this
step — see Blockers in the Step 3.1 report) records the exact provider version and
package checksums `terraform init` resolved. It is **not** gitignored anywhere in this
repo's `.gitignore`. Gitignoring it is a common template mistake: without it committed,
two machines (or a laptop and CI) can silently resolve different patch versions of the
same `~>` constraint, and a provider behavior difference shows up as a mysterious
plan/apply diff instead of a reviewed version bump.

## Default tags

`terraform/bootstrap/main.tf` defines the AWS provider's `default_tags`, applied to
every resource that provider instance creates:

| Tag | Source | Notes |
|---|---|---|
| `Project` | `var.project` | Defaults to `realworld-aws`. |
| `Environment` | `var.environment` | Defaults to `global` in bootstrap specifically, since bootstrap's state-storage resources are shared across every environment rather than belonging to one. Per-env compositions will set this to `dev` / `prod` once they gain their own provider block. |
| `ManagedBy` | hardcoded `"terraform"` | A statement of fact about the provider instance, not a per-environment choice, so it is not a variable. |
| `Owner` | `var.owner` | Defaults to `platform-team`; identifies who to page. |
| `CostCenter` | `var.cost_center` | Defaults to `engineering`; enables cost attribution in billing reports. |

`var.aws_region` deliberately has **no default**. The plan calls out the AWS region as
its own explicit decision checkpoint in Step 3.2 ("the region choice pins every later
resource"), so this step declares the variable but does not guess a value for it.

The `terraform/envs/<env>/<component>` folders do not yet have a provider block or
`variables.tf` — this step only scaffolds their version pins. A provider block (and,
presumably, `Environment = "dev"` / `"prod"` set explicitly rather than inherited) is
added once each component's real resources are designed.
