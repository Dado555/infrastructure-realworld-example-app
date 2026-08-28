# 0001 - Repository topology: four separate repos

**Date:** 2026-08-26
**Status:** Accepted

## Context

The platform spans a backend (Spring Boot), a frontend (Angular), infrastructure-as-code
(Terraform), and Kubernetes deployment manifests consumed by Argo CD. All four need
independent build, test, and release cadences. The backend and frontend are forks of
upstream open-source projects (`gothinkster/spring-boot-realworld-example-app` and
`gothinkster/angular-realworld-example-app`) that we want to keep pullable from origin.

## Decision

Use four separate repositories: `spring-boot-realworld-example-app` (backend),
`angular-realworld-example-app` (frontend), `infrastructure-realworld-example-app`
(Terraform), and `gitops-realworld-example-app` (Argo CD-watched manifests/values).

## Alternatives considered and rejected

- **Single monorepo (all four).** Would give atomic PRs across app and infra code and one
  CI config. Rejected because the backend and frontend are upstream forks we do not own —
  folding them into a monorepo destroys the ability to pull upstream changes with a clean
  `git merge`/`git fetch upstream`, and it makes "what did we actually change vs upstream"
  unreviewable in a single glance.
- **Three repos, with the GitOps manifests living inside the infra repo.** Fewer repos to
  manage, one less remote to configure Argo CD against. Rejected for a security reason, not
  a convenience one: CI needs *write* access to the GitOps repo (to bump image tags/digests
  after a build), while Argo CD needs only *read* access to it. Terraform code in that same
  repo can create IAM roles and other privileged resources. Combining them means the
  write-capable CI credential and the IAM-creating Terraform code share one blast radius —
  a compromised CI token could reach both GitOps commits and Terraform state/config in one
  step. Keeping them separate means a compromised GitOps-writing credential still cannot
  touch Terraform, and vice versa.

## Consequences

- Four remotes, four CI configs, four sets of branch protection rules to maintain.
- Cross-cutting changes (e.g., an API path change that touches backend, frontend, and
  GitOps values) require coordinated PRs across repos instead of one atomic commit.
- Upstream backend/frontend changes can be pulled in with standard fork workflows
  (`git remote add upstream ...`, periodic merge/rebase) without any infra-repo noise.
- The GitOps repo's write credential (CI) and its read credential (Argo CD) can be scoped
  independently from anything Terraform-related, keeping IAM-creation blast radius isolated.

## Revisit-when

One team owns all four repos long-term *and* cross-cutting changes (app + infra together)
become frequent enough that coordinating multi-repo PRs is a measured drag on velocity, or
a tool whose value depends on a single dependency graph (e.g., Nx, Bazel) is adopted for
this stack.
