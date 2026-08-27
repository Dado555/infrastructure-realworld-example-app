# 0011 - RDS-egress NetworkPolicy pulled forward from Step 7.7

**Date:** 2026-08-28
**Status:** Accepted

## Context

Step 5.5 put a default-deny-egress NetworkPolicy (DNS-only allow) on the
`app-dev`/`app-prod` namespaces. It's already live and enforced in the
cluster - enforcement required an explicit `enableNetworkPolicy` fix on the
VPC CNI, since proven working.

The master plan's matching backend-to-RDS egress-allow rule is scheduled at
Step 7.7 ("Application NetworkPolicies"), which comes after Ingress (7.5)
and HPA (7.6) - several steps after Step 7.2 ("Backend Deployment") actually
needs RDS connectivity. Step 7.2's backend pods use a readiness probe that
checks the database; without an egress-allow rule, those pods would never
reach Ready, for a reason unrelated to whether the Deployment itself is
correctly built.

## Decision

Pull forward just the backend-to-RDS portion of Step 7.7's NetworkPolicy
design and ship it now, before Step 7.2, as its own minimal permanent
addition in the GitOps repo
(`charts/realworld-backend/templates/networkpolicy.yaml` - a companion
piece of work happening in parallel with this ADR). It's a NetworkPolicy
scoped via podSelector to the backend chart's own selector labels, allowing
egress to the private-db subnet CIDRs (`10.0.20.0/24`, `10.0.21.0/24`) on
TCP/5432 only.

Step 7.7 still runs in its originally planned place and adds the rest of
the backend's rules (ingress from the ALB, ingress from Prometheus for
scraping, egress to AWS APIs on 443) plus the frontend's policies - by
extending this same NetworkPolicy resource/file, not duplicating the RDS
rule.

## Alternatives considered and rejected

- **Fold the RDS-egress rule directly into Step 7.2's own file scope**
  (same commit as the Deployment). Rejected - keeping it as its own
  separately reviewable change was the human's explicit preference.
- **Follow the plan literally**: run Step 7.2 as written, accept that
  backend pods stay NotReady until Step 7.7 lands several steps later.
  Rejected as leaving the app needlessly degraded for multiple steps to
  satisfy a literal step-numbering that the plan's own author likely didn't
  intend once Step 5.5's default-deny was confirmed live this early - Step
  7.7's own prerequisite line even says "Prerequisites: Step 7.5 working",
  i.e. it was never meant to gate basic pod readiness in the first place.

## Consequences

- Step 7.2's acceptance test (backend pods Ready, 0 restarts) can actually
  pass on its own merits once this lands, instead of failing for an
  environmental/sequencing reason unrelated to the Deployment's
  correctness.
- Step 7.7 becomes "extend the existing `networkpolicy.yaml` with the
  remaining rules" rather than "create it from scratch" - same end state as
  the plan, slightly different shape getting there.
- `app-prod` gets no equivalent rule yet - there's no prod RDS instance and
  no prod backend chart values yet, so there's nothing for a prod version
  of this rule to allow. Revisit when prod is actually built out (Phase 8's
  gated prod promotion, or later).

## Revisit-when

When Step 7.7 is executed, treat this ADR as already covering its
RDS-egress portion - don't re-add or duplicate that rule there, just add
the remaining ones (ALB ingress, Prometheus ingress, AWS-API 443 egress,
frontend policies) to the same file this ADR introduced.
