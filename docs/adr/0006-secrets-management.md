# 0006 - Secrets management: Secrets Manager + External Secrets Operator

**Date:** 2026-08-26
**Status:** Accepted

## Context

The backend needs a datasource credential and a JWT signing secret at runtime. Step 0.1
confirmed a concrete, currently-committed secret: `spring-boot-realworld-example-app/src/main/resources/application.properties`,
line 9, sets `jwt.secret=<literal value>` directly in source control (the literal value is
not reproduced here or anywhere in this ADR set, per this task's no-secrets-in-output
rule). This is a real, currently-exposed secret, not a hypothetical one.

## Decision

Use **AWS Secrets Manager** as the secret store, with the **External Secrets Operator
(ESO)** running under IRSA (IAM Roles for Service Accounts) to sync secrets into the
cluster as ordinary Kubernetes Secrets, consumed by the backend as environment variables.

**The currently-committed `jwt.secret` value must be treated as compromised.** When secrets
move to Secrets Manager, a **newly generated** JWT signing secret must be provisioned —
the committed value must not be copied into Secrets Manager and reused, since it has been
in git history (and, per Step 0.1, is world-readable in the public upstream-style repo).

## Alternatives considered and rejected

- **SSM Parameter Store + ESO.** `SecureString` parameters are free at the standard tier,
  versus Secrets Manager's roughly $0.40/secret/month. Rejected in favor of Secrets Manager
  because: (a) Secrets Manager has native rotation support that Parameter Store lacks
  natively, and (b) RDS's managed-master-password integration writes the database
  credential directly into Secrets Manager, not Parameter Store — using Parameter Store
  would mean maintaining a manual sync path for that credential instead of using AWS's
  built-in integration. At this secret count (a handful), the cost difference is noise
  (~$1.60/month total).
- **Application reads Secrets Manager directly via the AWS SDK, no Kubernetes Secret at
  rest.** Removes the "secret materialized in etcd" gap entirely (see below) and allows
  per-request fetching with no persistent copy. Rejected because it requires application
  code changes — adding AWS SDK calls and credential-fetching logic to a codebase we
  otherwise want to keep close to the upstream fork it was cloned from. ESO's approach
  needs zero application code changes: the app keeps reading ordinary environment
  variables, exactly as it does today.

## Consequences (including an honest gap)

- No application code changes are needed to consume secrets — ESO delivers a standard
  Kubernetes Secret, and the app reads env vars as it always has.
- **The honest gap:** ESO materializes the secret into etcd as a Kubernetes Secret, which by
  default is only base64-encoded, not encrypted, unless envelope encryption is explicitly
  enabled. Mitigations, both required:
  1. Enable **EKS secrets encryption with a KMS key at cluster creation time.** This cannot
     be added retroactively to an already-created cluster without a control-plane rebuild,
     so it must be set correctly the first time (tracked in the EKS control-plane step of
     the delivery roadmap).
  2. **RBAC scoping** restricting `get`/`list` on Secrets to only the specific
     ServiceAccount(s) that need them, not cluster-wide read access.
- Native rotation (Secrets Manager) and the RDS-managed master password integration are
  available without extra plumbing.
- The previously-committed JWT secret is rotated (replaced with a newly generated value),
  not migrated verbatim, when this decision is implemented.

## Revisit-when

Cost pressure becomes material at a much larger secret count (hundreds of secrets, where
Secrets Manager's per-secret price adds up) — at that point, reconsider SSM Parameter
Store. Or: a requirement emerges for per-request secret fetching with **no** at-rest
Kubernetes Secret copy and control over application code — at that point, reconsider direct
SDK reads.
