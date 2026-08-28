# Local Docker Compose stack

Brings up PostgreSQL, the Spring Boot backend, and the Angular frontend
together on one Docker network, reachable through a single origin (the
frontend's published host port) -- reproducing, locally, the single-origin
routing an ALB provides in AWS. Backend and frontend are built from their
own repos' own Dockerfiles as-is (`spring-boot-realworld-example-app`,
branch `feat/postgres-profile`; `angular-realworld-example-app`, branch
`feat/relative-api-url`) -- nothing in this directory rebuilds or edits
those. This directory only supplies the runtime wiring: `docker-compose.yml`,
env vars, and the local-only nginx config that adds the missing `/api`
reverse proxy (see `nginx-local.conf`'s own header comment for why that
proxy has to exist locally at all).

Requires those two sibling repos to be checked out next to this one, under
the same parent directory (`docker-compose.yml`'s `build.context` paths are
relative: `../../spring-boot-realworld-example-app` and
`../../angular-realworld-example-app`).

## Bring it up

```bash
cd local
cp .env.example .env
# Edit .env: set real local values for DB_PASSWORD and JWT_SECRET.
# Generate them, e.g. `openssl rand -base64 48` -- don't reuse old/example
# values, and don't reuse a value from any other environment.

docker compose up -d --build
```

`.env` is gitignored (see `.gitignore` in this directory) and must never be
committed -- only the placeholder `.env.example` is tracked.

## Check status

```bash
docker compose ps
```

All three services (`postgres`, `backend`, `frontend`) should show
`healthy`. First boot takes a while: Postgres init, then the backend's JVM
start + Flyway migration (`backend`'s healthcheck has a 45s `start_period`
before failures count), then the frontend depends on the backend being
healthy before it even starts.

Useful follow-ups:

```bash
docker compose logs backend | grep -i "flyway\|started"
docker compose logs -f            # tail all three
```

Through the single origin (replace the port with whatever you set
`FRONTEND_HOST_PORT` to, default 8080):

```bash
curl -sf http://localhost:8080/healthz
curl -sf http://localhost:8080/api/tags
```

The backend and its actuator port are also published directly
(`BACKEND_HOST_PORT`, default 8081; `BACKEND_MANAGEMENT_HOST_PORT`, default
8091) for debugging -- but the point of this stack is that nothing needs
those; everything works through the frontend's one origin, same as it will
through the ALB in production.

## Smoke test

`smoke-test.sh` is a scripted, repeatable proof that the full user journey
works end to end -- register, log in, read your own profile, create an
article, read it back, comment on it, favourite it, list it by tag, delete
it -- asserting on response **body content** at every step, not just HTTP
status (a 200 with an empty/wrong body is still a failure). It takes the
base URL as its one argument, so the exact same script also runs later
against dev and prod (see the implementation plan, Steps 7.5 and 8.x) --
nothing in it is specific to this Compose stack.

```bash
cd local
docker compose up -d          # if not already up
bash smoke-test.sh http://localhost:8080
```

A full run prints one `PASS: <step>` line per step it clears, and stops at
the first failure with a single `FAIL: <step> - <what was expected vs
got>` line, exiting non-zero -- it never continues past a failure
pretending things are fine. Requires `curl` and `jq` on `PATH` (checked
up front, with a clear message if either is missing).

Each run registers a freshly-generated, timestamp-suffixed username, email,
and article/tag, and a freshly-generated random password -- re-running the
script never collides with a previous run's data, and no credential is ever
hardcoded, reused, or printed.

### Current known-failing step: step 10 (tag-filtered listing)

As of this writing, `smoke-test.sh` **passes steps 1-9 and fails at step
10** (`GET /api/articles?tag=<the-tag-used>`), exiting non-zero. This is
expected, and is not a bug in the script or in this stack's wiring -- it is
this smoke test correctly catching a real, already-documented backend bug:
paginated/tag-filtered article listing (`GET /api/articles`, with or
without `?tag=`) returns HTTP 500 on PostgreSQL --
`org.postgresql.util.PSQLException: ERROR: LIMIT #,# syntax is not
supported` -- because `ArticleReadService.xml` uses MySQL/SQLite's
comma-form `LIMIT` syntax, which Postgres rejects outright. Full details,
the exact statements affected, and the fix are tracked in this repo at
`docs/adr/0005-database-engine-and-topology.md` -- not present on this
branch's working tree, but committed on the `docs/adr-0001-0008` branch
(commit `db09ad2`); check that branch out, or `git show
db09ad2:docs/adr/0005-database-engine-and-topology.md`, to read it.
Deliberately documented there rather than fixed here, per that ADR's own
explicit decision not to touch backend code outside a dedicated step.

Once that bug is fixed, step 10 should flip from `FAIL` to `PASS` with
**no changes needed to `smoke-test.sh`** -- it already asserts the correct,
real behaviour (the article we just created and favourited shows up in its
own tag's listing). If a future run exits 0, that's the signal the fix
landed and pagination/tag-filtering works against Postgres.

Because the run stops at step 10, the article, user, and comment it created
are left in the database rather than being cleaned up by step 11 (delete)
-- harmless, since every run's data is uniquely named and never collides
with a later run's.

### Fails fast when the stack is broken

`smoke-test.sh` also fails quickly and clearly -- not with a hang or a raw
`curl` error -- when a dependency is actually down. For example, with the
backend stopped:

```bash
docker compose stop backend
bash smoke-test.sh http://localhost:8080   # fails at an early step that needs
                                            # the backend (e.g. step 2, GET
                                            # /api/tags), in a few seconds,
                                            # with a clear FAIL message --
                                            # not step 10's known bug
docker compose start backend               # bring it back
docker compose ps                          # wait until backend shows "healthy"
```

## Tear down

Two very different commands:

- `docker compose down` -- stops and removes the containers/network, but
  **keeps** the named `postgres-data` volume. Data survives. This is the
  normal way to stop the stack.
- `docker compose down -v` -- also **deletes** the `postgres-data` volume.
  Destructive and irreversible for anything not backed up elsewhere. Only
  run this when you deliberately want a clean-slate reset (e.g. testing
  migrations from scratch, or the DB state is corrupted and you want to
  start over) -- never as routine cleanup.

To rebuild after pulling changes in either sibling repo, or after editing
`nginx-local.conf`:

```bash
docker compose up -d --build
```

(`--build` is only needed when the backend/frontend source or their
Dockerfiles changed, or when `nginx-local.conf` changed and you want the
new mount picked up on a fresh container -- `docker compose restart
frontend` also works for a config-only nginx change since the file is
bind-mounted, not baked in.)
