# 0009 - CI-to-AWS auth: IAM user access keys, not OIDC

**Date:** 2026-08-27
**Status:** Accepted

## Context

Step 4.4 built GitHub OIDC federation exactly per the original plan: an
`aws_iam_openid_connect_provider` plus 4 roles trust-scoped to specific
repo+ref/environment conditions, no long-lived keys anywhere. Step 4.5 tried
to prove it works end to end and every `sts:AssumeRoleWithWebIdentity` call
was denied, even though the trust policy, OIDC provider registration, and
repo/branch names all checked out correct on inspection (confirmed via
CloudTrail: the request reached AWS and was denied at authorization, not
token validation).

This AWS account (`262786914511`) turned out to be a **member account in an
AWS Organization we don't control** - the account owner gets "you don't have
permission" trying to view Organizations settings even as root on this
account. The most likely cause is a Service Control Policy at the
organization's management account blocking external OIDC federation, which
this account has no visibility or ability to change.

## Decision

Fall back to IAM users with access keys stored as GitHub Actions secrets,
in place of the 4 OIDC-federated roles. The OIDC provider and the 4
`gha-*` roles from Step 4.4 are removed (real resources, deleted).

Kept as-is: the same 4-way identity split (backend push, frontend push,
infra plan, infra apply) and the same scoped permission policies designed
in Step 4.4 - only the trust/authentication mechanism changes, not who can
do what.

## Alternatives considered and rejected

- **Ask the org admin to allow this OIDC provider.** Rejected for now: no
  contact/control over the management account from here. Not ruled out
  forever - if that changes, OIDC is the better mechanism and worth
  revisiting.
- **Stand up a separate AWS account outside this organization.** Rejected:
  means abandoning the VPC/security-groups/ECR/KMS already applied in this
  account and redoing Phase 3-4 elsewhere, for a portfolio project where
  that cost isn't justified by the benefit.

## Consequences

- Long-lived AWS credentials now exist in GitHub Actions secrets - the
  exact thing the plan's constitution explicitly says to avoid ("no AWS
  keys in GitHub secrets"). This is a real, accepted security regression
  from the original design, not a wash.
- Mitigations: one IAM user per identity (same narrow scope as the OIDC
  roles had), keys stored only as encrypted GitHub secrets (repo or
  environment scoped, never committed), no key ever printed or logged
  during setup, and the infra-apply secret goes on a GitHub Environment
  (`prod`) so it can still require manual approval the same way the OIDC
  design intended.
- Key rotation is now a manual/scheduled responsibility - OIDC tokens are
  short-lived by design and need no rotation; static keys do. Worth a
  reminder on a recurring basis (e.g. rotate every 90 days) since nothing
  enforces this automatically.

## Revisit-when

If this AWS account ever leaves the restrictive organization, or the org
admin allows the GitHub OIDC provider, switch back to Step 4.4's original
OIDC design and delete the IAM users/keys.
