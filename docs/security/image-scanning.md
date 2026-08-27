# Image Vulnerability Scanning — Baseline & Policy

Step 2.5 of the RealWorld AWS implementation plan. Establishes the real vulnerability
baseline for the two locally-built container images before either is pushed to ECR,
and defines the recommended CI gating policy.

Scanned images (already built in Steps 2.1 / 2.2 — **not rebuilt for this step**):

| Image | Size | Base image | Notes |
|---|---|---|---|
| `realworld-backend:local` | 663MB | `eclipse-temurin:11-jre-jammy` (Ubuntu 22.04) | Spring Boot 2.6.3, packaged as `app/app.jar` |
| `realworld-frontend:local` | 74.4MB | `nginx-unprivileged:1.27-alpine` (Alpine 3.21.3) | Static assets only, no application-dependency layer |

Scanner: [Trivy](https://trivy.dev) `0.74.0`, run via its official Docker image
(`aquasec/trivy`) against the local Docker daemon — nothing installed on the host.
Scan date: 2026-08-27.

## 1. Reproducing the scans

Trivy is not installed locally on this machine. All scans were run via Trivy's
official Docker image, mounting the host's Docker socket so Trivy can inspect
already-built local images without needing a registry:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity HIGH,CRITICAL realworld-backend:local
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity HIGH,CRITICAL realworld-frontend:local

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --scanners vuln,secret realworld-backend:local
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --scanners vuln,secret realworld-frontend:local

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity CRITICAL --exit-code 1 realworld-backend:local
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity CRITICAL --exit-code 1 realworld-frontend:local

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --scanners secret realworld-backend:local
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --scanners secret realworld-frontend:local
```

**Windows / Git Bash note:** the bare command above fails on this machine with
`mkdir C:\Program Files\Git\var: Access is denied` — Git Bash's MSYS path
translation rewrites `/var/run/docker.sock` into a Windows path before Docker ever
sees it. Fix: prefix every invocation with `MSYS_NO_PATHCONV=1` so the path is
passed through literally to the Docker Desktop engine, e.g.:

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity HIGH,CRITICAL realworld-backend:local
```

This was verified with `aquasec/trivy --version` (returned `Version: 0.74.0`) and a
smoke scan of `alpine:latest` before being relied on for the real scans below. Once
that env var is set, the socket mount works cleanly — no further adjustment needed.

For exact per-CVE severity, package version and "Fixed Version" data, `--format
json` was used and parsed programmatically; `--format table` (the default) was used
for the human-readable summaries below.

## 2. Findings: CRITICAL / HIGH counts, base-OS vs. application-dependency, fix availability

### `realworld-backend:local` — 83 HIGH/CRITICAL findings total

| Layer | Target | CRITICAL | HIGH | Fix available |
|---|---|---|---|---|
| Base OS (Ubuntu 22.04, 143 packages) | `realworld-backend:local (ubuntu 22.04)` | **0** | **0** | n/a — 48 LOW/MEDIUM findings only, no HIGH/CRITICAL at the OS layer |
| Application dependencies (Java, `app/app.jar`) | `Java` (jar) | **17** | **66** | 17/17 CRITICAL have a fix; 65/66 HIGH have a fix; **1 HIGH has no fix** |

**100% of the backend's HIGH/CRITICAL burden comes from the application-dependency
(Spring Boot 2.6.3) layer, not the base OS image.** This matches the plan's
expectation exactly (B3 — EOL Spring Boot stack).

All 17 CRITICAL findings, with fixed versions:

| Package | CVE | Installed | Fixed version(s) |
|---|---|---|---|
| org.apache.tomcat.embed:tomcat-embed-core | CVE-2025-24813 | 9.0.56 | 11.0.3, 10.1.35, 9.0.99 |
| org.apache.tomcat.embed:tomcat-embed-core | CVE-2026-41293 | 9.0.56 | 9.0.118, 10.1.55, 11.0.22 |
| org.apache.tomcat.embed:tomcat-embed-core | CVE-2026-43512 | 9.0.56 | 9.0.118, 10.1.55, 11.0.22 |
| org.apache.tomcat.embed:tomcat-embed-core | CVE-2026-43515 | 9.0.56 | 9.0.118, 10.1.55, 11.0.22 |
| org.postgresql:postgresql | CVE-2024-1597 | 42.3.1 | 42.2.28, 42.3.9, 42.4.4, 42.5.5, 42.6.1, 42.7.2 |
| org.springframework.boot:spring-boot-actuator-autoconfigure | CVE-2023-20873 | 2.6.3 | 3.0.6, 2.7.11, 2.6.15, 2.5.15 |
| org.springframework.security:spring-security-config | CVE-2023-34034 | 5.6.1 | 5.6.12, 5.7.10, 5.8.5, 6.0.5, 6.1.2 |
| org.springframework.security:spring-security-core | CVE-2022-22978 | 5.6.1 | 5.5.7, 5.6.4, 5.4.11 |
| org.springframework.security:spring-security-core | CVE-2022-31692 | 5.6.1 | 5.7.5, 5.6.9 |
| org.springframework.security:spring-security-web | CVE-2022-22978 | 5.6.1 | 5.5.7, 5.6.4, 5.4.11 |
| org.springframework.security:spring-security-web | CVE-2024-38821 | 5.6.1 | 5.7.13, 5.8.15, 6.2.7, 6.0.13, 6.1.11, 6.3.4 |
| org.springframework.security:spring-security-web | CVE-2026-22732 | 5.6.1 | 6.5.9, 7.0.4 |
| org.springframework:spring-beans | CVE-2022-22965 | 5.3.15 | 5.2.20.RELEASE, 5.3.18 |
| org.springframework:spring-web | CVE-2016-1000027 | 5.3.15 | 6.0.0 |
| org.springframework:spring-webflux | CVE-2022-22965 | 5.3.15 | 5.2.20.RELEASE, 5.3.18 |
| org.springframework:spring-webmvc | CVE-2022-22965 | 5.3.15 | 5.2.20.RELEASE, 5.3.18 |
| org.springframework:spring-webmvc | CVE-2023-20860 | 5.3.15 | 6.0.7, 5.3.26 |

All 17 have a fixed version available (Trivy's `Fixed Version` column is populated
for every one). None of these fixes are reachable without either bumping individual
dependency versions (risky against a Spring Boot 2.6.3 parent BOM) or upgrading
Spring Boot itself — see the Decision Required section below.

The single HIGH finding with **no fix available**:

| Package | CVE | Installed | Fixed version |
|---|---|---|---|
| org.springframework:spring-expression | CVE-2026-41849 | 5.3.15 | **NO FIX** |

The other 65 HIGH findings (Tomcat, Jackson, Spring Framework/Security/HATEOAS,
protobuf, graphql-java, logback, snakeyaml, sqlite-jdbc, micrometer, json-smart) all
have a fixed version listed by Trivy — full list is reproducible via the commands in
Section 1.

### `realworld-frontend:local` — 33 HIGH/CRITICAL findings total

| Layer | Target | CRITICAL | HIGH | Fix available |
|---|---|---|---|---|
| Base OS (Alpine 3.21.3) | `realworld-frontend:local (alpine 3.21.3)` | **2** | **31** | **33/33 (100%) have a fix available** |
| Application dependencies | — | — | — | not applicable — static assets only, no scanned language-package layer |

**100% of the frontend's HIGH/CRITICAL findings are base-OS (Alpine package)
findings, and every single one already has a fixed package version published.**
Per the triage rule below, these are the "usually fixed by moving to a newer/
different base image tag" category — a `nginx-unprivileged:1.27-alpine` rebuild
(or an in-image `apk upgrade`) once Alpine's package index has caught up would
very plausibly clear all 33.

The 2 CRITICAL findings:

| Package | CVE | Installed | Fixed version |
|---|---|---|---|
| libcrypto3 | CVE-2026-31789 | 3.3.3-r0 | 3.3.7-r0 |
| libssl3 | CVE-2026-31789 | 3.3.3-r0 | 3.3.7-r0 |

The 31 HIGH findings span `c-ares`, `libcrypto3`/`libssl3` (OpenSSL, 6 more CVEs),
`libexpat` (4), `libpng` (6), `libxml2` (4), `musl`/`musl-utils` (1 each), `nghttp2-libs`,
and `zlib` — all Alpine OS packages, all with a fixed version published.

### Exit-code policy check (`--severity CRITICAL --exit-code 1`)

| Image | CRITICAL count | Exit code |
|---|---|---|
| `realworld-backend:local` | 17 | **1** (fail) |
| `realworld-frontend:local` | 2 | **1** (fail) |

Both images would currently fail a CI gate configured to fail on any CRITICAL
finding, consistent with the counts above.

## 3. Secret scan — confirms zero secrets in either image

```
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --scanners secret realworld-backend:local
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --scanners secret realworld-frontend:local
```

Both runs completed with exit code `0` and **zero secret findings** on both images.
Trivy's table output shows the Secrets column as `-` ("not scanned" for that
target type — package-manifest targets aren't secret-scan targets) rather than a
non-zero count; the `--format json` output for both scans confirms this
unambiguously: neither report contains a `Secrets` key anywhere in `Results` (Trivy
only emits that key when at least one secret is found), and no separate
filesystem/config-file target was created for either image. This is the expected,
correct outcome.

This validates that **Step 1.5's JWT-secret externalization actually holds at the
image layer**, not just in source — no secret material was baked into either
built image.

## 4. Recommended CI policy

**Fail CI on CRITICAL-with-an-available-fix. Do not fail CI on every HIGH finding.**

This is stated guidance from the plan itself (not a new decision made here), so it
does not require separate human sign-off — it's documented here as the policy this
project follows, and why:

- Failing on *every* HIGH finding makes the pipeline permanently red from
  unfixable or slow-to-land base-image CVEs (exactly what we see above: 65/66 HIGH
  findings on the backend and all 31 HIGH findings on the frontend are fixable in
  principle, but fixing them means a Spring Boot upgrade or an Alpine package/base
  image bump — not something that should block every single CI run on every commit
  until that larger work lands).
- Teams that adopt an "everything red until fixed" policy tend to respond by
  disabling the scan outright once it becomes permanently red noise — which is a
  worse security posture than a scan that reports meaningfully and gates on the
  finding class that is (a) most severe and (b) has a concrete, actionable fix.
  CRITICAL-with-fix-available is exactly that class: it flags "there is a known
  remediation and someone should apply it," while unfixable/HIGH findings are
  surfaced for visibility and triage rather than as a hard gate.
- Findings with **no fix available** (e.g. the backend's `CVE-2026-41849` on
  `spring-expression`) should never be a hard CI gate regardless of severity — there
  is nothing actionable to do about them today beyond removing the dependency
  entirely, and a hard gate on an unfixable CVE simply blocks all future commits
  with no path to green.

Concretely, once this project has a CI pipeline: `trivy image --severity CRITICAL
--ignore-unfixed --exit-code 1 <image>` (the `--ignore-unfixed` flag is the
mechanical implementation of "CRITICAL-with-an-available-fix") is the recommended
gate. HIGH findings and any-severity findings without a fix should be reported
(e.g. uploaded as a build artifact or posted as a PR comment) but not block the
build.

## 5. DECISION REQUIRED — accept EOL Spring Boot 2.6.3, or scope a Boot-upgrade phase?

**This decision is explicitly NOT made in this document or by this step.** The plan
calls this out as the largest open scope question in the project. What follows is
the evidence; the choice between the two options below is for a human to make.

**The evidence, in one sentence:** all 83 of the backend's HIGH/CRITICAL findings
(17 CRITICAL, 66 HIGH) live entirely in the application-dependency layer tied to
Spring Boot 2.6.3 and its bundled Spring Framework 5.3.15 / Spring Security 5.6.1 /
Tomcat 9.0.56 — the Ubuntu 22.04 base OS layer contributes zero HIGH/CRITICAL
findings. 82 of those 83 have a fixed version already published; only 1 (a HIGH,
`spring-expression` CVE-2026-41849) has no fix at all under the current major
version line.

**Option A — Accept EOL Spring Boot 2.6.3 as a documented, stated risk.**
Appropriate if this stays a portfolio/demo project where the CRITICAL findings are
acceptable given the deployment context (e.g. not internet-facing with real user
data, or accepted as "known limitation, out of scope"). Under the recommended CI
policy in Section 4, the pipeline would need `.trivyignore` entries or an explicit
"accepted risk" annotation for all 17 CRITICAL CVEs listed in Section 2 (each with
an expiry/review date) so CI can go green without a real fix — otherwise it stays
permanently red on this image, which contradicts the stated goal of a meaningful CI
gate. That tradeoff should be made consciously, not by default.

**Option B — Treat a Spring Boot upgrade as a new, separately-scoped phase of
work.** Spring Boot 2.6.3 → a supported 3.x line (or later) is a major-version jump
across Spring Boot, Spring Framework, Spring Security, and the Jakarta EE
namespace migration (`javax.*` → `jakarta.*`) — genuinely new scope, not a patch.
It would resolve the majority of the 83 findings at once (new Boot version pulls in
patched Tomcat/Jackson/Spring transitively) but requires its own planning,
regression testing, and is unrelated to the infra work this plan otherwise covers.

No `.trivyignore` file was added in this step for either the backend or frontend
repo: every fixable finding is a candidate for a real fix (Alpine bump for
frontend, Boot upgrade or Option A's accepted-risk annotation for backend) rather
than blanket suppression, and the one unfixable finding (spring-expression,
HIGH, no fix) does not need suppression because it does not trip the recommended
CRITICAL-with-fix CI gate in the first place. Adding a `.trivyignore` now, before
the human decision above is made, would be speculative and was explicitly out of
scope per this step's instructions.
