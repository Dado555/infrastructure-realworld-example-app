# 0014 - CODEOWNERS review gate on gitops envs/prod/ is inert for a solo contributor

**Date:** 2026-08-28
**Status:** Accepted

## Context

Step 8.4 wired `.github/CODEOWNERS` (`/envs/prod/** @Dado555`) plus branch
protection on the gitops repo's `main` (required status checks, `require_code_owner_reviews: true`,
`enforce_admins: false`) so that changes to production manifests need a
human review before merge.

Verified live, three times, to rule out a sequencing artifact rather than a
real platform limitation:

1. First test (before PR #1 merged): a PR touching `envs/prod/` showed
   `reviewDecision: REVIEW_REQUIRED` / `mergeStateStatus: BLOCKED`. Looked
   correct, but this was a false positive - GitHub evaluates CODEOWNERS from
   the PR's **base ref**, and `main` didn't have `.github/CODEOWNERS` yet.
   The block was actually coming from an over-broad
   `required_approving_review_count: 1` set on every PR, unrelated to
   CODEOWNERS matching.
2. Fixed the over-broad setting (`required_approving_review_count: 0`, so
   only CODEOWNERS-matched paths carry any review requirement), merged PR
   #1 (CODEOWNERS now genuinely lives on `main`, confirmed via
   `GET /repos/.../codeowners/errors` returning `{"errors":[]}`), then
   re-tested.
3. A fresh PR touching `envs/prod/.codeowners-test`, opened by `@Dado555`
   (the same account listed as the sole owner for that path) against the
   now-correct `main`: `reviewDecision: ""`, `reviewRequests: []`,
   `mergeStateStatus: CLEAN` once checks passed. No review was requested at
   all.

GitHub does not count a PR author's own approval toward any review
requirement, and it will not assign a code-owner review to someone who is
both the only listed owner for the touched path and the PR's author - it
silently drops the requirement rather than creating a blocking, unsatisfiable
state. `git log`/`git remote` confirm `@Dado555` is this repo's only
contributor. There is currently no second person to review anything.

## Decision

Ship Step 8.4's CODEOWNERS + branch protection exactly as designed (this is
the mechanism the plan calls for, and it is correctly configured). Accept
that, as currently staffed, it is a no-op for prod-touching PRs: they merge
without any review being requested, same as any other PR. Do not weaken the
non-prod path or add a workaround reviewer to manufacture a signal that
wouldn't reflect real review.

## Alternatives considered and rejected

- **`required_approving_review_count: 1` globally.** Rejected: doesn't
  solve the self-review problem either (an author's own approval still
  doesn't count), it just makes it universal - every PR, prod or not, would
  permanently need an explicit `gh pr merge --admin` bypass. Worse than the
  status quo, not better.
- **Add a second GitHub account/bot as a rubber-stamp reviewer.** Rejected:
  more moving parts for an approval that carries no real review signal if
  the "reviewer" isn't actually evaluating the change - false confidence is
  worse than an honestly-absent gate.

## Consequences

- Prod manifest changes currently merge on `@Dado555`'s own say-so, same as
  any other change - the CODEOWNERS mechanism exists and is correctly wired,
  but contributes nothing extra today.
- The moment a second real collaborator is added to this repo, this gate
  starts working automatically with zero code/config changes - the
  CODEOWNERS file and branch protection are already correct for that case.
- `enforce_admins: false` remains set for the unrelated, legitimate reason
  of letting the repo owner override required status checks if genuinely
  needed - not the mechanism resolving this gap (there's no deadlock to
  bypass; the requirement never engages for a self-authored PR in the first
  place).

## Revisit-when

A second collaborator joins this repo - re-verify the gate actually
requests their review on a real `envs/prod/` PR before relying on it.
