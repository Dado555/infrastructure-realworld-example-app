# 0004 - Frontend hosting, API path strategy, and frontend lint tooling

**Date:** 2026-08-26
**Status:** Accepted

## Context

Two coupled questions: (1) where the Angular frontend is served from, and (2) how the
frontend reaches the backend API. A poor answer to (2) forces environment-specific builds
or CORS configuration, which undermines the "one immutable image, promoted across
environments" goal. A short third question (frontend lint tooling) is folded in here
because it was raised as a byproduct of inspecting the frontend repo, not because it is
architecturally related.

Step 0.1 confirmed two concrete facts relevant to this decision:

- The backend currently serves its routes at the domain root, with **no `/api` prefix**
  and **no `server.servlet.context-path` set** anywhere in
  `spring-boot-realworld-example-app/src/main/resources/application.properties`.
- The frontend currently hardcodes an **absolute external URL** in
  `angular-realworld-example-app/src/app/core/interceptors/api.interceptor.ts`, line 4:
  every request is rewritten to `https://api.realworld.show/api${req.url}`. This is a
  fork-specific hardcoding pointed at the public demo API, not a relative path.

Neither of these has been changed yet — both are recorded here as the current state this
decision reacts to; the actual code changes are out of scope for this step and belong to a
later implementation step.

## Decision

- **Frontend hosting:** containerized nginx serving the Angular build, deployed in EKS
  behind the **same ALB** as the backend. Same origin: `/api/*` routes to the backend
  Service/target group, `/*` routes to the frontend. Zero CORS configuration required.
- **API path strategy:** set `server.servlet.context-path=/api` on the backend (a single
  Spring property), and change the frontend's interceptor to call a **relative** `/api`
  path instead of the current absolute `https://api.realworld.show/api` URL. This makes the
  built frontend artifact identical across dev and prod — nothing environment-specific is
  baked in at build time, so the same image is promotable dev -> prod.
- **Frontend lint tooling:** keep **Prettier-only** for now; do not adopt `angular-eslint`
  in this step.

## Alternatives considered and rejected

### Frontend hosting

- **S3 + CloudFront.** Cheaper (no pod/node share), globally faster, no container image to
  patch, and the frontend repo already has static-hosting artifacts (e.g. a `_redirects`
  file) suggesting it was built with this in mind. Rejected for v1 on three concrete points:
  1. *CORS reappears.* A CloudFront domain separate from the ALB's domain breaks the
     same-origin property, requiring a Spring Security CORS filter chain and preflight
     handling to be added and maintained — real failure surface for a small cost saving.
  2. *Immutable promotion breaks.* With a relative `/api` path there is nothing
     environment-specific in the build; S3 hosting reintroduces the problem because bucket
     contents differ per environment, forcing either per-environment builds or a runtime
     `config.json` fetch (an added bootstrap round-trip and failure mode).
  3. *GitOps visibility gap.* S3 deployment is an imperative `aws s3 sync` plus a CloudFront
     invalidation from CI — a push Argo CD cannot see, cannot detect drift on, and cannot
     roll back via Git revert. Half the estate would be GitOps-managed and half would not.
  S3+CloudFront remains a documented future enhancement: CloudFront can sit *in front of*
  the ALB with two cache behaviors (`/api/*` uncached, `/*` cached), keeping the same-origin
  property and GitOps visibility while adding CDN benefits.

### API path strategy

- **Rewrite at the ingress/ALB instead of setting `context-path`.** Would avoid touching
  Spring config. Rejected because `context-path` is a single property that survives any
  future ingress change, whereas an ALB rewrite rule is infrastructure-side state that has
  to be kept in sync with the application's actual route set.
- **Point the frontend at the bare host with no `/api` segment at all.** Avoids the path
  question entirely but conflicts with the RealWorld frontend's conventional expectation of
  an `/api/...` base and would require rewriting every interceptor/service call, not just
  the one hardcoded location Step 0.1 found.

### Frontend lint tooling

- **Adopt `angular-eslint` now.** Would close the "no linter" gap immediately and give a
  more capable static-analysis gate than Prettier alone. Rejected for now under YAGNI: the
  repo has shipped without a linter and no specific inconsistency has been observed in
  review that ESLint would have caught; adding it preemptively is speculative tooling
  overhead (new config file, new CI step, potential churn fixing pre-existing violations)
  for a problem not yet demonstrated.

## Consequences

- Backend and frontend must be deployed behind the same ALB/hostname for the same-origin
  property to hold; this couples their Kubernetes Ingress configuration together.
- The `context-path=/api` change and the interceptor's relative-path change are both
  required before the frontend will work against the backend in any environment — until
  then the current absolute-URL behavior persists. This step only records the decision; the
  code changes are tracked as later implementation steps.
- No CORS filter chain needs to be built or maintained.
- CI/CD promotes one image across environments with no per-environment rebuild.
- The frontend continues without a linter; `format:check` (Prettier) plus a TypeScript
  typecheck remain the only static gates in CI.

## Revisit-when

- **Frontend hosting:** global latency becomes a measured problem and a tested CORS
  configuration already exists, or frontend traffic volume is large enough that serving it
  from pods is a meaningful cost line — at that point, move to the documented
  CloudFront-in-front-of-ALB enhancement rather than a CORS-requiring split origin.
- **ESLint adoption:** a real inconsistency shows up in code review that Prettier's
  formatting-only scope cannot catch (e.g., an unused-import bug, an unsafe `any`, a
  React/Angular-specific anti-pattern) — at that point adopt `angular-eslint` rather than
  continuing to defer it.
