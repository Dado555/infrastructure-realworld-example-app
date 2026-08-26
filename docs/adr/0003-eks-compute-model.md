# 0003 - EKS compute model: managed node group

**Date:** 2026-08-26
**Status:** Accepted

## Context

The platform needs a Kubernetes compute layer for two application Deployments (backend,
frontend) plus an observability plane (CloudWatch agent, Fluent Bit, node-exporter,
Prometheus/Grafana). Workload shape is flat and predictable — two services, no bursty or
heterogeneous demand.

## Decision

Use an EKS managed node group: 2 nodes, in private subnets.

## Alternatives considered and rejected

- **Fargate.** No nodes to patch, per-pod billing, appealing operationally. Rejected because
  it breaks the observability requirement directly: Fargate does not run DaemonSets, so the
  CloudWatch agent, Fluent Bit, and node-exporter — the three components that deliver the
  centralized-logs and Kubernetes-metrics requirements — have nowhere to run. Fargate also
  has no persistent EBS volumes, so Prometheus cannot retain history across pod restarts.
  Fargate is a good fit for stateless workloads dropped into a cluster that *already has* an
  observability plane running elsewhere; it is a poor fit for a cluster whose job is to
  *build* that observability plane.
- **Karpenter.** Just-in-time, right-sized node provisioning with strong bin-packing and
  Spot-instance handling. Rejected as solving a problem this workload does not have: two
  Deployments with flat, predictable demand give Karpenter nothing to bin-pack or
  right-size. Running Karpenter here would mean operating an additional controller for no
  measurable benefit over a static 2-node managed group.

## Consequences

- Node patching/upgrades are our responsibility (managed node group handles AMI rollout
  mechanics, but upgrade timing and draining are ours to schedule).
- DaemonSets (CloudWatch agent, Fluent Bit, node-exporter) run without any workaround.
- Persistent EBS-backed volumes are available for Prometheus's local TSDB.
- Fixed node count means we pay for 2 nodes regardless of instantaneous load — acceptable
  given the flat, predictable workload this decision is scoped to.

## Revisit-when

Bursty or heterogeneous workloads appear (candidate: Karpenter), or a single workload needs
kernel-level tenancy isolation that only Fargate's per-pod sandboxing provides.
