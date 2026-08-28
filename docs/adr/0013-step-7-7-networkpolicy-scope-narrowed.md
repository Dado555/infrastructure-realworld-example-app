# 0013 - Step 7.7 NetworkPolicy scope narrowed to one real rule

**Date:** 2026-08-28
**Status:** Accepted

## Context

Step 7.7's stated scope was: backend ingress from the ALB, backend ingress from
the Prometheus namespace, backend egress to RDS/CoreDNS/AWS-APIs-443, frontend
ingress from the VPC CIDR, frontend egress DNS-only. By the time this step was
reached, ADR 0011 (RDS egress) and ADR 0012 (ALB ingress, both charts) had
already pulled most of this forward out of necessity - Step 7.2 and 7.5
couldn't work without them. Checking what was actually still missing:

- **RDS egress (backend):** already live, ADR 0011.
- **ALB ingress (both charts):** already live, ADR 0012.
- **CoreDNS egress (both charts):** never needed a per-app rule - Step 5.5's
  `default-deny-egress-allow-dns` NetworkPolicy already allows DNS for every
  pod in `app-dev`/`app-prod` at the namespace level. Adding an identical
  per-app rule would be pure duplication.
- **Frontend "ingress from the VPC CIDR":** ADR 0012's ALB-ingress rule
  already does this, scoped even tighter than the plan asked for (the two
  public-subnet CIDRs specifically, not the whole VPC CIDR).
- **Backend egress to AWS APIs on 443:** checked `build.gradle` - the backend
  has **zero** AWS SDK dependencies. It never calls an AWS API directly.
  Checked `external-secrets` namespace (where the actual AWS-API caller,
  ESO, runs) - it has no default-deny NetworkPolicy at all, so the plan's
  own stated failure mode for this rule ("breaks ESO refresh") doesn't
  describe anything `app-dev`'s policies could affect either way.
- **Backend ingress from the Prometheus namespace:** genuinely new, not
  covered by anything above. Phase 9 doesn't exist yet, but the rule is
  namespace-scoped (`observability`) rather than pod-label-scoped, so it's
  safe to add now - it simply matches zero pods until Phase 9 deploys
  something there.

## Decision

Add exactly one new NetworkPolicy resource:
`charts/realworld-backend/templates/networkpolicy.yaml` gained a third
resource, `<fullname>-ingress-prometheus`, allowing ingress on port 8081
(management/metrics port) from any pod in the `observability` namespace,
scoped via podSelector to `component: server` (same convention as the other
two rules in this file). Everything else Step 7.7 asked for either already
existed (ADR 0011/0012) or doesn't apply to this specific application
(AWS-API egress - no SDK dependency to justify it).

Ran the full Step 2.4 smoke test (11/11 steps) against the live dev ALB
after adding this rule, per the plan's own "does the smoke test still pass"
decision checkpoint - unaffected. Also ran the plan's negative test: an
unlabeled busybox pod in `app-dev` attempting to reach the backend's
management port on 8081 times out (denied), while the same pod's DNS query
gets a real answer (proving the deny is targeted, not a general network
break).

## Alternatives considered and rejected

- **Add the AWS-API-443 egress rule anyway, "just in case."** Rejected -
  granting egress nobody currently needs is the opposite of what these
  NetworkPolicies exist to enforce (least privilege). If the backend ever
  gains a real AWS SDK dependency, add the rule at that point, next to the
  code that needs it - matching how ADR 0011's RDS rule and this ADR's
  Prometheus rule were both added exactly when something concrete needed
  them.
- **Duplicate the DNS-allow rule per-app for symmetry with the RDS/ALB
  rules.** Rejected - the namespace-level rule from Step 5.5 already covers
  every pod in the namespace; a per-app copy would be redundant YAML with
  no behavioral difference, and two separate `networkpolicy.yaml` mechanisms
  doing the same job at different scopes invites drift.
- **Scope the Prometheus rule to a specific pod label now** (guessing at
  kube-prometheus-stack's eventual label scheme). Rejected - Phase 9 hasn't
  picked or configured that chart yet; a namespace-only selector is correct
  today and doesn't need revisiting once Phase 9 actually deploys something,
  since it'll match automatically as long as it lands in `observability`.

## Consequences

- `charts/realworld-backend/templates/networkpolicy.yaml` now holds three
  resources (egress-rds, ingress-alb, ingress-prometheus);
  `charts/realworld-frontend/templates/networkpolicy.yaml` holds the one
  ADR 0012 already added and needs nothing further from this step.
- Phase 9's Prometheus deployment should be able to scrape the backend's
  management port without any additional NetworkPolicy work, as long as it
  lands in the `observability` namespace - verify this is genuinely true
  when Phase 9 actually builds it (the plan's own acceptance test says
  "check targets in Phase 9", which this ADR defers to, not skips).
- If the backend ever adds a real AWS SDK call, add the corresponding
  egress-to-443 rule at that time rather than assuming it's already covered.

## Revisit-when

Phase 9, when Prometheus is actually deployed: confirm scrape targets show
healthy for the backend, using this ADR's namespace-scoped rule as-is. If
kube-prometheus-stack's scraper turns out to run outside the `observability`
namespace, or needs a different port, adjust the existing
`ingress-prometheus` resource rather than adding a second one.
