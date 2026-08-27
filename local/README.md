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
