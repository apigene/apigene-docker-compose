# AGENTS.md

## Repo role

Runs the full Apigene platform locally or on-prem with Docker. One URL serves the web UI, API, docs, and MCP gateway. Includes MongoDB and Redis.

Does **not** own:
- Application source code → `apigene-backend`, `apigene-copilot`, `apigene-mcp-next`
- Kubernetes deployment → `apigene-helm-chart`
- Desktop installer → `apigene-desktop` (bundles a copy of this stack)

## Sibling repos

| Repo | Relationship |
|------|--------------|
| `apigene-backend` | `backend` service image |
| `apigene-copilot` | `copilot` service image |
| `apigene-mcp-next` | `mcp-gw` service image |
| `apigene-helm-chart` | K8s equivalent of this stack |
| `apigene-desktop` | Syncs this repo into `resources/stack` |

## Start here

| Area | Path |
|------|------|
| CLI entrypoint | `apigene` |
| Compose definition | `docker-compose.yml` |
| Env template | `.env.example` |
| Helper scripts | `lib/cmd_*.sh`, `lib/defaults.sh` |
| Integration tests | `tests/integration.sh` |
| Nginx routing | `nginx.conf` |

## Routing

| Path | Service |
|------|---------|
| `/` | copilot (UI) |
| `/api/*` | backend |
| `/docs`, `/redoc`, `/openapi.json` | backend |
| `/agent/<name>/mcp` | mcp-gw |

Default URL: `http://localhost:8080` (or `APIGENE_PORT`).

## Common change paths

### Change service config or env

1. Update `.env.example` with documented defaults
2. Adjust `docker-compose.yml` if service wiring changes
3. Update `lib/defaults.sh` if derived URLs change
4. Run `./apigene test` and `./tests/integration.sh`

### Change routing

1. Edit `nginx.conf`
2. Verify health endpoints and MCP path still work
3. Update README routing table

### Pin or upgrade images

1. Set `APIGENE_IMAGE_TAG` in `.env` (default `latest` in example)
2. `./apigene start --pull`
3. Align version with `apigene-helm-chart` `imageTag` for releases

## Local dev

```bash
git clone https://github.com/apigene/apigene-docker-compose.git
cd apigene-docker-compose
chmod +x apigene
./apigene setup
./apigene test
./tests/integration.sh
```

| Command | Purpose |
|---------|---------|
| `./apigene setup` | Create `.env`, pull images, start |
| `./apigene start` | Start all services |
| `./apigene start --pull` | Pull latest images, then start |
| `./apigene test` | Health checks |
| `./apigene logs [service]` | Tail logs |
| `./apigene stop` | Stop (keeps Mongo data) |

## Env vars that matter

- `APIGENE_PORT` — host port nginx binds to (default `8080`)
- `APIGENE_IMAGE_TAG` — pin release or use `latest`
- `DATABASE_ENV` — logical data isolation (default `local`)
- `AUTH_APIGENE_SECRET_KEY` — auto-generated on setup; change for production
- `NEXT_PUBLIC_SERVER_BASE_URL` — only needed for custom domain/LAN/HTTPS

## Conventions

- **CLI:** Bash scripts in `lib/`; main entrypoint is `./apigene`
- **Auth default:** Apigene API key; set `NEXT_PUBLIC_AUTH_PROVIDER=clerk` for Clerk OAuth
- **Production:** Pin image tags; do not rely on `latest`

## Cross-repo impact

| Change here | Also update |
|-------------|-------------|
| New service or port | `apigene-helm-chart` chart templates |
| Env var used by apps | `apigene-backend` / `apigene-copilot` `.env.example` |
| MCP URL format | `apigene-docs`, `apigene-mcp-next` |
| Desktop bundle | `apigene-desktop` via `npm run sync-stack` |

## Safe defaults for agents

- Prefer `./apigene test` over manual curl checks
- Document new env vars in `.env.example` and README
- Do not commit `.env` with real secrets
- Keep nginx routing table in sync with README
