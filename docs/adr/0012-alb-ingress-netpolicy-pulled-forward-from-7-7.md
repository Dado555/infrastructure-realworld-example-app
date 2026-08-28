# 0012 - ALB ingress-allow NetworkPolicy pulled forward from Step 7.7

**Date:** 2026-08-28
**Status:** Accepted

## Context

Step 5.5's default-deny-ingress NetworkPolicy has been live and enforced on
`app-dev`/`app-prod` since Phase 5 (companion to the default-deny-egress
policy documented in ADR 0011). The master plan's matching ingress-allow
rule for ALB traffic is scheduled at Step 7.7 ("Application NetworkPolicies")
- but Step 7.5 (ALB Ingress) needs it immediately: the ALB uses
`target-type: ip`, so its health-check and request traffic arrives directly
at pod IPs from the ALB's ENIs in the public subnets, not through a
Kubernetes-native path that any existing policy already permitted.

Deploying Step 7.5's Ingress without this rule produced a real, live
failure: both target groups showed every target `unhealthy` with reason
`Target.Timeout` immediately after the ALB was created - the default-deny
policy was silently dropping the ALB's health-check probes. This is the
exact same shape of problem ADR 0011 already fixed for RDS egress, just on
the ingress side this time.

## Decision

Pull forward the ALB ingress-allow portion of Step 7.7's NetworkPolicy
design and ship it now, before Step 7.5 is considered done, as a permanent
addition in the GitOps repo. Two new NetworkPolicy resources:
`charts/realworld-backend/templates/networkpolicy.yaml` (added as a second
resource in the same file as ADR 0011's egress rule) and
`charts/realworld-frontend/templates/networkpolicy.yaml` (new file). Both
scoped via podSelector to `app.kubernetes.io/component: server` (excluding
the backend's migration Job, which needs no ALB ingress), allowing ingress
from the two public-subnet CIDRs (`10.0.0.0/24`, `10.0.1.0/24` - where the
ALB's ENIs live, confirmed via the LoadBalancer's actual subnet mapping) on
the relevant ports: 8080 + 8081 for the backend (traffic + management/health
port), 8080 only for the frontend.

Step 7.7 still adds the rest of its planned rules (ingress from Prometheus
for scraping, egress to AWS APIs on 443, any remaining hardening) later, by
extending these same files rather than duplicating the ALB-ingress rule.

## Alternatives considered and rejected

- **Scope the ingress-allow to the ALB's specific security group** instead
  of the subnet CIDR. Rejected for now - NetworkPolicy's `ipBlock` selector
  works on IP/CIDR, not AWS security group identity, so CIDR-based scoping
  to the public subnets is the correct mechanism at the Kubernetes layer;
  the security group itself provides a second, AWS-layer restriction
  in front of this.
- **Fold this into Step 7.5's Ingress commit directly** rather than a
  separate NetworkPolicy-only commit. Rejected for consistency with ADR
  0011's precedent (RDS-egress got its own commit too) and because the
  target-group failure was diagnosed and fixed as a distinct, identifiable
  unit of work.

## Consequences

- Step 7.5's ALB target groups reach `healthy` and the full request path
  (frontend SPA, backend API, SPA deep links) works end-to-end through the
  real ALB - verified directly via `aws elbv2 describe-target-health` and
  the Step 2.4 smoke test script.
- Step 7.7 becomes "extend the existing `networkpolicy.yaml` files with the
  remaining rules" for both charts, same pattern ADR 0011 already
  established for the backend's egress rule.
- The CIDR scoping (public subnets only) means only ALB-originated traffic
  can reach these pods on their service ports - not arbitrary VPC traffic,
  not other namespaces, not the internet directly (the ALB's own security
  group is the outer gate; this NetworkPolicy is the inner one).

## Revisit-when

When Step 7.7 is executed, treat this ADR as already covering both charts'
ALB-ingress portion - don't re-add or duplicate those rules, just add
Prometheus-scrape ingress and AWS-API egress (backend) plus anything else
Step 7.7 specifies, to the same files this ADR and ADR 0011 introduced.
