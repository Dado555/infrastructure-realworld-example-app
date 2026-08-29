# 0015 - Prod reuses dev's VPC, EKS cluster, and RDS instance

**Date:** 2026-08-29
**Status:** Accepted

## Context

Step 8.6's plan text lists "`app-prod` namespace and prod RDS ready" as a
prerequisite, and its acceptance tests assume a genuinely separate prod
environment (`argocd app get realworld-backend-prod` syncing against real
infra, a smoke test against a distinct prod domain). Checked live before
starting: the `app-prod` namespace exists (created early, alongside
`app-dev`, with matching PSA labels/quota/LimitRange - Step 5.5), but nothing
else does. `aws rds describe-db-instances` shows only `realworld-aws-dev-db`.
`aws ec2 describe-vpcs` shows only the dev VPC. `terraform/envs/prod/{network,
data,platform}` have scaffolding (`backend.tf`, `backend.hcl`, `versions.tf`)
but no actual resources and no state - this project has only ever built
`dev`, across the entirety of Phases 3-7.

Provisioning a genuinely separate prod environment (VPC, subnets, NAT gateway,
Multi-AZ RDS per ADR 0005's original topology decision, its own ALB) is a
real, costly, multi-step undertaking of its own - comparable in scope to
Phases 3-7 repeated a second time. Asked the user how to proceed; the answer
was to reuse the existing dev infrastructure rather than build a second
environment.

## Decision

Prod runs on the same physical AWS resources as dev, isolated at the
Kubernetes/application layer instead of the infrastructure layer:

- **Same VPC, same EKS cluster, same 2 nodes.** Prod pods land in the
  existing `app-prod` namespace, scheduled onto the same node pool as dev.
  Fits within existing capacity at `minReplicas: 1` per app (confirmed live:
  5 free pod slots existed before adding prod's 2 steady-state pods).
- **Same RDS instance, separate database.** A new `realworld_prod` database
  is created on `realworld-aws-dev-db` (not a new instance). Prod's
  `DB_URL` points at `realworld_prod`; dev's stays on `realworld`. Data is
  isolated; the underlying instance, and its master credential
  (`realworld_admin`), are not - both environments' `DB_USERNAME`/
  `DB_PASSWORD` resolve to the same RDS-managed secret.
- **Separate JWT signing secret.** `prod/realworld/app` (new Secrets Manager
  secret, mirrors `dev/realworld/app`'s structure) so a dev-issued token can
  never authenticate against prod. Unlike dev's secret, this one is NOT
  encrypted with a dedicated CMK - it uses Secrets Manager's default AWS-
  managed key, avoiding a new KMS resource (and its IAM-grant wiring) for a
  environment that is otherwise entirely reusing dev's infrastructure.
- **Same ALB, separate listener port.** No second domain exists (dev itself
  is ALB-DNS + HTTP only, per the Step 7.5 decision). Prod gets its own ALB
  listener on port 8080 via `alb.ingress.kubernetes.io/listen-ports`, sharing
  the existing `IngressGroup` (`realworld-dev`) and therefore the existing
  ALB, target-group infrastructure, and access-log bucket. `group.order`
  30/40 for prod's backend/frontend (dev already uses 10/20).
- **ESO's IAM policy widened, not re-scoped.** The existing pod-identity role
  keeps its narrow `secretsmanager:GetSecretValue`/`DescribeSecret` grant,
  now covering `dev/realworld/*` OR `prod/realworld/*` (two explicit
  wildcards, still never `secretsmanager:*` or `Resource: "*"`) plus the
  shared RDS master secret it already had access to.
- **`terraform/envs/prod/network` and `terraform/envs/prod/platform` stay
  empty** - nothing to provision there under this design. Only
  `terraform/envs/prod/data` gets real content, and only the JWT-secret
  piece of it (no RDS module block, unlike dev/data).

## Alternatives considered and rejected

- **Full separate prod environment** (new VPC, Multi-AZ RDS, second EKS
  node group or cluster, own ALB). Rejected for now per the user's explicit
  direction - real, ongoing AWS cost (roughly 2x the RDS spend alone for
  Multi-AZ) for a portfolio/demo project, and a scope well beyond "wire up a
  gated promotion job."
- **Path-based prod routing** (`/prod/api`, `/prod/`) instead of a second
  listener port. Rejected: the frontend's Angular build assumes it's served
  from `/` (no `base href` override built for a subpath), so this would have
  required a frontend code change outside this step's scope. A second
  listener port needs zero app-repo changes and is a well-supported ALB
  Controller feature (confirmed live: the ALB's security group is fully
  controller-managed, so a new `listen-ports` entry gets its inbound rule
  added automatically, no manual Terraform SG change needed).

## Consequences

- **No real blast-radius isolation between dev and prod.** A bad node, a
  VPC-level misconfiguration, an EKS control-plane issue, or RDS instance
  downtime affects both environments simultaneously - the single most
  important property a real prod environment provides is absent here. This
  is an explicit, accepted demo-scoped compromise, not an oversight.
- **Shared RDS master credential.** Anyone with prod's `DB_USERNAME`/
  `DB_PASSWORD` (from the ExternalSecret-synced `realworld-app` k8s Secret in
  `app-prod`) also has the credential valid against dev's database, and vice
  versa - though each can only reach the database they're configured to
  connect to unless someone deliberately changes `DB_URL`. A real production
  system would never share a master credential across environments.
- **Shared node capacity.** Prod's pods compete with dev's for the same 2
  nodes. Currently fits (both apps at `minReplicas: 1`), but headroom is
  thin (this project already hit a "too many pods per node" wall once, in
  Step 6.3, before nodes were restored to 2). Revisit node count or enable
  VPC CNI prefix delegation (already identified as the free fix, not yet
  applied) if capacity pressure recurs.
- **The promotion mechanism itself (PR-gated, CODEOWNERS-reviewed, prod
  stays unchanged while the PR is open) is fully real and unaffected by this
  decision** - it's exactly what Step 8.6 asks for, just pointed at infra
  that happens to be shared rather than dedicated.

## Revisit-when

This project needs to demonstrate genuine environment isolation (e.g. before
any real production traffic, or if asked to show a "real" prod topology for
a portfolio review) - at that point, apply the already-scaffolded
`terraform/envs/prod/{network,data,platform}` for real, following the same
shape as `dev`'s, and cut prod over from the shared RDS database/EKS
namespace to its own instance/cluster.
