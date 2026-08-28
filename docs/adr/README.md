# Architecture Decision Records

Initial architecture decisions for the RealWorld AWS platform (backend, frontend,
infrastructure, and GitOps repos), recorded from the design rationale worked out during
platform planning plus the findings of the Step 0.1 repository inspection. Each ADR is
self-contained: Context, Decision, Alternatives considered and rejected, Consequences, and
an explicit Revisit-when condition.

Read in order for the full log in about ten minutes; each is independently referenceable.

| ADR | Title | Summary | Status |
|---|---|---|---|
| [0001](0001-repository-topology.md) | Repository topology | Four separate repos (backend, frontend, infra, gitops) instead of a monorepo or infra+gitops combined — upstream-fork pullability and CI credential isolation drive the split. | Accepted |
| [0002](0002-iac-tooling.md) | IaC tooling | Plain Terraform with per-environment/component backend config files, not Terragrunt or workspaces — duplication is too small to justify a wrapper, and workspaces would put dev and prod in one state file. | Accepted |
| [0003](0003-eks-compute-model.md) | EKS compute model | EKS managed node group (2 nodes, private subnets), not Fargate or Karpenter — Fargate can't run the DaemonSets the observability plane needs; Karpenter has no bin-packing problem to solve here. | Accepted |
| [0004](0004-frontend-hosting-and-api-integration.md) | Frontend hosting, API path, and lint tooling | Containerized nginx in EKS behind the same ALB as the backend (same-origin, zero CORS); backend gets `server.servlet.context-path=/api`, frontend's hardcoded absolute API URL (`api.interceptor.ts` line 4) moves to a relative `/api` path; frontend stays Prettier-only for now, no ESLint. | Accepted |
| [0005](0005-database-engine-and-topology.md) | Database engine version and topology | Dev single-AZ `db.t4g.micro` / prod Multi-AZ `db.t4g.small`, 7-day/30-day backup retention — decided. **RDS PostgreSQL engine version is explicitly UNRESOLVED**, blocked on confirming the Flyway version this Spring Boot 2.6.3 app resolves to. | Accepted (topology) / **Unresolved** (engine version) |
| [0006](0006-secrets-management.md) | Secrets management | AWS Secrets Manager + External Secrets Operator via IRSA, not SSM Parameter Store or direct SDK reads — zero application code changes, native rotation, RDS-managed password integration. Committed `jwt.secret` (line 9 of the backend's `application.properties`) must be rotated, not reused. | Accepted |
| [0007](0007-deployment-model.md) | Deployment model | Argo CD (pull-based GitOps), not direct `kubectl`/`helm` from GitHub Actions or Flux — the deciding factor is credential shape: CI never holds cluster-reach credentials, only ECR push rights. | Accepted |
| [0008](0008-migration-strategy.md) | Database migration strategy | Flyway as a Kubernetes Job registered as an Argo CD PreSync hook, with `spring.flyway.enabled=false` in the deployed app — avoids startup-migration races and CrashLoopBackOffs; a GitHub Actions migration job is blocked outright since hosted runners can't reach a private RDS. Requires expand/contract migration discipline. | Accepted |

## Open items tracked across these ADRs

- **RDS PostgreSQL engine version (ADR 0005):** left open pending running
  `./gradlew dependencies` locally to confirm the resolved Flyway version. Nothing in
  Phase 6 of the delivery roadmap (RDS provisioning) can proceed with a concrete engine
  version until this is closed.
- **ESLint adoption (ADR 0004):** currently deferred (Prettier-only), with an explicit flip
  condition (a real inconsistency Prettier can't catch shows up in review) rather than a
  permanent no.
