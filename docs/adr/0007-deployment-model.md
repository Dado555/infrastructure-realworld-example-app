# 0007 - Deployment model: GitOps with Argo CD

**Date:** 2026-08-26
**Status:** Accepted

## Context

Deployment needs a mechanism to roll out backend and frontend image updates to EKS across
dev and prod. The two live options are: GitHub Actions applying manifests directly against
the cluster, or a pull-based GitOps controller reconciling from a Git repo (ADR 0001
already separated that GitOps repo from the Terraform-holding infra repo for credential-
isolation reasons).

## Decision

Use **Argo CD** for deployment. GitHub Actions builds and publishes container images (and
commits the new tag/digest to the GitOps repo); Argo CD is solely responsible for applying
that GitOps repo's state to the cluster.

## Alternatives considered and rejected

- **GitHub Actions runs `kubectl apply` / `helm upgrade` directly against the cluster.**
  Fewer moving parts, one place to look for what happened, faster feedback loop (no
  reconciliation delay). Rejected primarily on **credential shape**: direct deploy requires
  giving GitHub-hosted runners cluster-reach credentials (a kubeconfig or equivalent
  cluster-admin-adjacent role) and network access to the EKS API server. Pull-based GitOps
  inverts that relationship — the cluster reaches out to Git, and CI holds nothing more
  privileged than ECR push rights. A compromised CI token in the direct-deploy model can act
  on the cluster; in the GitOps model it cannot. Secondary factor: direct deploy has no
  built-in drift detection — a manual `kubectl edit` against the live cluster persists
  silently until the next deploy happens to overwrite it, whereas Argo CD surfaces drift
  continuously.
- **Flux.** Same GitOps model and pull-based reconciliation as Argo CD, generally
  considered lighter-weight, no bundled UI. This was judged a **legitimate alternative**,
  not a rejected-on-merits choice — Argo CD was picked specifically because its UI makes
  sync status, diffs, and rollback directly demonstrable, which has value for a portfolio-
  style project where reviewers benefit from being able to see state visually rather than
  only via CLI output.

## Consequences

- CI (GitHub Actions) never holds cluster-reach credentials — only ECR push permissions and
  GitOps-repo write access (the latter scoped and isolated per ADR 0001).
- Rollback is a `git revert` on the GitOps repo, which Argo CD then reconciles — no direct
  cluster mutation required to roll back.
- Drift between the cluster's actual state and the GitOps repo's declared state is detected
  and surfaced automatically by Argo CD rather than silently persisting.
- An additional component (Argo CD itself) must be installed, upgraded, and operated inside
  the cluster.
- Deploys are not instantaneous — they depend on Argo CD's sync/reconciliation cycle rather
  than happening synchronously inside the CI run (mitigated where needed by triggering a
  sync from CI rather than waiting for the poll interval).

## Revisit-when

The project shrinks to a single-service scope where GitOps ceremony (a second repo, an
in-cluster controller, reconciliation delay) costs more than the credential-isolation and
drift-detection benefits it buys, or the organization has already standardized on Flux
elsewhere and consistency with that standard outweighs Argo's UI advantage.
