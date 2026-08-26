# 0005 - Database engine version and dev/prod topology

**Date:** 2026-08-26
**Status:** Accepted for topology and backup retention; **UNRESOLVED** for the RDS
PostgreSQL engine version (see Context and Revisit-when).

## Context

The backend (Spring Boot 2.6.3) uses Flyway (`org.flywaydb:flyway-core`, version managed by
the Boot 2.6.3 BOM) for schema migrations, which currently run on application startup
against the local datasource. Flyway's PostgreSQL support is version-gated: a Flyway release
refuses to run ("Unsupported Database") against a PostgreSQL major version newer than it
knows about at the time it was released.

**This is currently constrained and unresolved.** Step 0.1 could not confirm the exact
Flyway version this application resolves to, because a local Java toolchain was not
installed and `./gradlew dependencies --configuration runtimeClasspath | grep -i flyway`
could not be run. The Spring Boot 2.6.3 BOM is understood to pin a Flyway 8.0.x line, which
would reject PostgreSQL versions newer than it recognized at release time (this is an
inference from the BOM, not a confirmed, resolved version — see the plan's finding B7). The
RDS PostgreSQL engine version therefore cannot be finalized yet.

## Decision

**Decision framework (to apply once unblocked):** pick the newest PostgreSQL major version
that the actually-resolved Flyway version accepts. If the desired/newest PostgreSQL engine
version is rejected by Flyway, resolve the conflict one of two ways: (a) pin RDS to an
older PostgreSQL engine version Flyway does accept, or (b) override Flyway's resolved
version explicitly in `build.gradle` (independent of the Spring Boot BOM) so it supports a
newer PostgreSQL major. No specific engine version is chosen in this ADR.

**Topology (decided, independent of the engine-version question):**
- **Dev:** single-AZ, `db.t4g.micro`.
- **Prod:** Multi-AZ, `db.t4g.small`.

**Backup retention (decided):**
- **Dev:** 7 days.
- **Prod:** 30 days.

## Alternatives considered and rejected

### Topology

- **Single-AZ everywhere.** Roughly halves the RDS bill. Rejected for prod: prod's
  availability bar requires automatic failover on an AZ or instance failure, which only
  Multi-AZ provides; single-AZ prod turns routine instance maintenance into a customer-
  visible outage.
- **Multi-AZ everywhere (including dev).** Consistent configuration across environments,
  and dev would genuinely exercise failover behavior. Rejected because Multi-AZ roughly
  doubles instance cost for a standby that buys nothing when dev's actual availability bar
  is "the developer notices and re-runs" — that cost is better spent elsewhere.

### Backup retention

- **7 days everywhere (the platform's stated minimum).** Simpler, one number to reason
  about. Rejected for prod specifically: backups protect against *logical* damage (a bad
  migration, an errant `DELETE`) at least as often as hardware failure, and this class of
  damage is frequently noticed days after it happens — 7 days of point-in-time recovery has
  repeatedly proven too short a window in practice. 30 days is the smallest retention
  defensible for prod; dev keeps the 7-day minimum since its data has no recovery
  expectation beyond "re-seed it."

### Engine version — why not just pick one now

- **Pick a recent PostgreSQL version (e.g., 16) and move on.** Rejected outright: doing so
  without knowing the resolved Flyway version risks choosing an engine version Flyway 8.0.x
  will refuse to run against, which would only surface as a startup failure much later
  (Phase 6/7 of the delivery roadmap), far from its actual cause. Guessing here is exactly
  the kind of invented fact this ADR process exists to avoid.

## Consequences

- No RDS engine version can be provisioned yet; the Terraform RDS module's engine-version
  variable stays a placeholder/TODO until this is resolved.
- Dev and prod diverge in cost and resilience by design (Multi-AZ prod costs roughly double
  a single instance's price for the standby).
- Prod's 30-day backup retention costs more in storage than the 7-day minimum but is the
  explicit trade favoring detectability of logical corruption over storage savings.
- Any Terraform planning or apply that depends on the RDS engine version (Phase 6 in the
  delivery roadmap) is blocked until this ADR's open question is closed.

## Revisit-when

**Revisit once `./gradlew dependencies` can be run locally and the exact Flyway version is
confirmed.** At that point, apply the decision framework above (newest PostgreSQL major
Flyway accepts, or an explicit Flyway version override in `build.gradle`) to pick a
specific RDS engine version, and update this ADR's status to fully Accepted with the
version recorded.
