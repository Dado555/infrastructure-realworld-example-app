# 0005 - Database engine version and dev/prod topology

**Date:** 2026-08-26 (engine version resolved 2026-08-27)
**Status:** Accepted for topology and backup retention; RDS PostgreSQL engine version
**resolved to PostgreSQL 14** (see Decision). One open known issue tracked below.

## Context

The backend (Spring Boot 2.6.3) uses Flyway (`org.flywaydb:flyway-core`, version managed by
the Boot 2.6.3 BOM) for schema migrations, which currently run on application startup
against the local datasource. Flyway's PostgreSQL support is version-gated: a Flyway release
refuses to run ("Unsupported Database") against a PostgreSQL major version newer than it
knows about at the time it was released.

**Resolved (Step 1.1):** `./gradlew dependencies --configuration runtimeClasspath` confirms
the Spring Boot 2.6.3 BOM resolves Flyway to **8.0.5**, and the live `bootRun` log
independently corroborates this (`Flyway Community Edition 8.0.5 by Redgate`). Flyway 8.0.x
added PostgreSQL 14 support at release; PostgreSQL 15 requires Flyway 9+, which this BOM does
not provide.

## Decision

**Engine version: PostgreSQL 14.** Chosen as the newest major version the resolved Flyway
8.0.5 accepts, per the decision framework below. Empirically validated in Steps 1.2/1.3:
the app's single migration (`V1__create_tables.sql`) applied cleanly to a real
`postgres:14` container with zero SQL changes needed, `flyway_schema_history` shows
`success=true`, and a live MyBatis read (`GET /tags`) round-tripped correctly.

**Decision framework (for reference / if a future PostgreSQL major is considered):** pick
the newest PostgreSQL major version that the actually-resolved Flyway version accepts. If a
desired newer PostgreSQL engine version is rejected by Flyway, resolve the conflict one of
two ways: (a) pin RDS to an older PostgreSQL engine version Flyway does accept, or (b)
override Flyway's resolved version explicitly in `build.gradle` (independent of the Spring
Boot BOM) so it supports a newer PostgreSQL major.

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

## Known issue — MySQL-dialect LIMIT syntax breaks pagination on PostgreSQL

**Not fixed. Deliberately deferred — tracked here, not in code, per an explicit decision not
to touch production code outside a dedicated step.**

Step 1.7's Testcontainers PostgreSQL integration suite
(`src/test/java/io/spring/infrastructure/PostgresIntegrationTest.java` in the backend repo)
found that `src/main/resources/mapper/ArticleReadService.xml` (lines 61 and 99, statements
`queryArticles` and `findArticlesOfAuthors`) uses MySQL/SQLite's comma-form
`limit #{page.offset}, #{page.limit}`. PostgreSQL rejects this outright:
`ERROR: LIMIT #,# syntax is not supported`. This breaks `ArticleQueryService`'s
offset/limit-based article listing, tag filtering, and user-feed queries — i.e. **article
pagination and tag filtering will fail the moment the `postgres` profile serves this kind of
request.** The cursor-based listing path (`limit #{page.queryLimit}`, a single value) is
unaffected.

Two of `PostgresIntegrationTest`'s six scenarios (pagination, tag filtering) fail against
this bug and were left failing intentionally, as evidence, rather than weakened to pass.
Create-user, create-article, favoriting, and commenting all pass with real data assertions
against live PostgreSQL.

**The fix, when someone picks this up:** change both statements to
`limit #{page.limit} offset #{page.offset}` — valid syntax on both MySQL and PostgreSQL, so
it doesn't regress the SQLite/default profile. `PostgresIntegrationTest`'s two currently-red
cases are the acceptance criteria; they should flip green with no other test changes.

## Consequences

- Dev and prod diverge in cost and resilience by design (Multi-AZ prod costs roughly double
  a single instance's price for the standby).
- Prod's 30-day backup retention costs more in storage than the 7-day minimum but is the
  explicit trade favoring detectability of logical corruption over storage savings.
- **The backend cannot correctly serve paginated or tag-filtered article listings against
  PostgreSQL until the known issue above is fixed.** This blocks relying on the `postgres`
  profile for anything beyond the write/read paths Step 1.7 confirmed working
  (users, articles-by-slug, favorites, comments) — it does not block RDS provisioning itself
  (Terraform doesn't care about MyBatis SQL), but it should be fixed before any real traffic
  hits Postgres-backed pagination, and certainly before Phase 6 (RDS) is treated as done.

## Revisit-when

**Engine version:** resolved — no further action needed unless a future requirement forces a
newer PostgreSQL major, in which case re-apply the decision framework above against
whatever Flyway version is current at that time.

**Known issue (LIMIT syntax):** revisit before the backend is pointed at real RDS
PostgreSQL for production traffic (Phase 6 of the delivery roadmap), or sooner if any
change in this repo starts requiring correct pagination/tag-filtering support against
Postgres for a local/dev workflow.
