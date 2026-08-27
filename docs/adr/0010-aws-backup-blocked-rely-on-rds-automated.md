# 0010 - AWS Backup blocked by org SCP, rely on RDS automated backups

**Date:** 2026-08-27
**Status:** Accepted

## Context

Step 6.4 built a daily AWS Backup plan for the RDS instance (vault, plan,
tag-based selection, IAM role) exactly per the original design. Applying it
failed on the very first resource:

```
AccessDeniedException: ... backup:CreateBackupVault ... explicit deny in a
service control policy: arn:aws:organizations::184812644717:policy/o-8ong6gi47q/service_control_policy/p-7enx3l07
```

Same shape of problem as ADR 0009 (GitHub OIDC federation blocked by an org
SCP) - this AWS account is a member account in an organization we don't
control, and its SCP explicitly denies the AWS Backup service, not just one
action. Everything up to the vault (IAM role, policy attachment, KMS key +
alias) had already been created before the failure; all four were destroyed
immediately after, so nothing from this attempt is left running.

## Decision

Drop the AWS Backup vault/plan/selection for this account. Rely on RDS's
own automated backups (already live since Step 6.1: `backup_retention_period
= 7`, daily window `03:00-04:00 UTC`) as the actual, working backup
coverage for the database. The `terraform/modules/backups` module is kept
in the repo, unused, as a ready-to-use reference - same treatment as
`modules/github-oidc-role` in ADR 0009.

## Alternatives considered and rejected

- **RDS manual snapshots via a different mechanism** (`aws_db_snapshot` /
  EventBridge-scheduled snapshots, bypassing the AWS Backup service
  entirely). Considered, not attempted - the user chose the simpler
  RDS-automated-backups path instead once it was pointed out RDS already
  provides real, working daily backup coverage today. Worth revisiting if
  RDS's built-in retention (max 35 days) is ever not enough.
- **Ask the org admin to allow AWS Backup.** Same practical dead end as
  ADR 0009 - no contact/control over the management account from here.

## Consequences

- No independent, separately-retained backup copy exists outside RDS's own
  automated backup/PITR mechanism. If RDS's own backup subsystem is ever
  itself the point of failure (not the historical case, but not zero-risk
  either), there's no AWS Backup vault as a second copy.
- No monthly-retained snapshots (the plan's prod design called for 1-year
  monthly retention) - moot for now since prod isn't built, but worth
  remembering if prod ever is.
- Phase 9's Prometheus EBS volume (when built) will have no automated
  backup coverage at all under this decision - EBS snapshots would need
  their own mechanism if that ever matters, since AWS Backup was the
  plan's only answer for EBS.
- RDS's own retention caps at 35 days; AWS Backup would have let dev go
  beyond that if ever wanted. Not a real constraint at 7 days retention.

## Revisit-when

If this AWS account ever leaves the restrictive organization, or the org
admin allows the AWS Backup service, switch back to the
`terraform/modules/backups` module (already written, just needs its
module call restored in `terraform/envs/dev/data`) rather than starting
over.
