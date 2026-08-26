# 0008 - Database migration strategy: Flyway as an Argo CD PreSync hook

**Date:** 2026-08-26
**Status:** Accepted

## Context

The backend currently runs Flyway migrations on application startup (the default Spring
Boot behavior, confirmed present in Step 0.1 — `flyway-core` is on the classpath and no
migration-disabling configuration exists). This is fine for a single instance but becomes a
liability once the deployment model in ADR 0007 (Argo CD-managed rollouts) can run more
than one backend replica.

## Decision

Run Flyway as a **Kubernetes Job registered as an Argo CD `PreSync` hook**, with the
deployed application's startup migration explicitly **disabled**
(`spring.flyway.enabled=false`). Argo CD runs this Job before rolling out any new
application pods for a sync, waits for it to succeed, and aborts the sync if it fails.

## Alternatives considered and rejected

- **Migrate on application startup (current behavior).** Simplest — no extra Job, no extra
  hook configuration, matches what the app already does. Rejected as the platform's replica
  count grows past 1: every replica starting up races to run migrations concurrently.
  Flyway's own locking mitigates simultaneous execution but does not eliminate the race
  entirely, and — more importantly — a failed migration under this model manifests as a
  **CrashLoopBackOff**, where the visible symptom ("pods won't start") is disconnected from
  the actual cause (buried in one pod's startup logs). That is a bad on-call experience by
  design, not just a theoretical risk.
- **A GitHub Actions job runs migrations before the GitOps commit that triggers the
  deploy.** Would keep migration execution in CI, visible in the same pipeline as the
  build. Rejected outright — this has a **hard blocker**, not just a trade-off: GitHub-
  hosted runners cannot reach a private RDS instance. Making this work would require either
  a self-hosted runner inside the VPC or a bastion host, or exposing RDS publicly — the
  last of which directly violates the platform's requirement that RDS stay private. In-
  cluster execution (the PreSync hook) already has the necessary network reach without any
  of these workarounds.

## Consequences

- Migration failures **block the sync** — old pods keep serving traffic rather than new
  pods entering a crash loop. This is a direct, intended consequence of the PreSync hook
  ordering guarantee.
- `spring.flyway.enabled=false` must be set in every deployed environment's configuration;
  if it is ever left enabled alongside the hook, replicas would race the Job (a documented
  failure mode to guard against during Helm chart / values review).
- **Expand/contract discipline is now mandatory**, not optional: a release may add a
  nullable column, backfill it, and start writing to it; the *next* release starts reading
  it; a *later* release drops the old column. Add-and-drop must never happen in the same
  release. This is what keeps `git revert` of the application safe — the previous image
  must still run correctly against the newer (already-migrated) schema, which only holds if
  no release both adds and removes in the same step.
- Flyway's `undo` capability is a paid feature and is explicitly **not** part of this
  design — migrations are forward-only. A bad migration is fixed by writing and shipping a
  new migration, never by editing history or hand-editing `flyway_schema_history`.
- The Argo CD hook's delete policy must not be `HookSucceeded` in a way that deletes a
  *failed* Job's pod — the failed pod's logs are the primary debugging artifact when a
  migration breaks and must be preserved (a configuration detail for the implementation
  step, recorded here so it isn't lost).

## Revisit-when

The schema is small and the application stays single-replica indefinitely (startup
migration becomes low-risk again), or self-hosted runners already exist inside the VPC for
other reasons — at that point, a GitHub Actions migration job becomes viable and would give
earlier feedback (failing in CI before any GitOps commit) than the PreSync hook does.
