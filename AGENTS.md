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
| Image command tests | `tests/images.sh` (no engine needed) |
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

1. Set `APIGENE_IMAGE_TAG` in `.env` (default `latest`). Override one service with `APIGENE_BACKEND_IMAGE_TAG`, `APIGENE_COPILOT_IMAGE_TAG`, `APIGENE_MCP_GW_IMAGE_TAG`, or `APIGENE_NGINX_IMAGE_TAG`. Backend and the worker share the backend tag.
2. `APIGENE_IMAGE_REGISTRY` defaults to `public.ecr.aws/apigene/` (trailing slash). Leave it empty for images already on the machine (`apigene-backend:<tag>`). Optional `APIGENE_*_IMAGE_NAME` overrides the published name.
3. `./apigene start --pull` — skips Apigene images whose resolved ref is `name:tag`, and still pulls MongoDB and Redis.
4. Align the public tag with `apigene-helm-chart` `imageTag` for releases.

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
| `./apigene start --pull` | Pull images, then start. Skips local `name:tag` images |
| `./apigene images save` | Pull the stack images and write `apigene-images.tar.gz` |
| `./apigene images load` | Load that archive into Docker or Podman |
| `./apigene images push <registry>` | Push loaded images to a private registry, for the Helm chart's `images.mirror` |
| `./apigene test` | Health checks |
| `./apigene logs [service]` | Tail logs |
| `./apigene stop` | Stop (keeps Mongo data) |

## Env vars that matter

- `APIGENE_PORT` — host port nginx binds to (default `8080`)
- `APIGENE_IMAGE_REGISTRY` — registry prefix with trailing slash; empty uses local `name:tag` images
- `APIGENE_IMAGE_TAG` — default tag for every Apigene image (`latest` or a pinned release)
- `APIGENE_BACKEND_IMAGE_TAG`, `APIGENE_COPILOT_IMAGE_TAG`, `APIGENE_MCP_GW_IMAGE_TAG`, `APIGENE_NGINX_IMAGE_TAG` — optional per-image tags
- `APIGENE_IMAGE_PLATFORM` — default `linux/amd64`; set `linux/arm64` for locally built Apple Silicon images
- `DATABASE_ENV` — logical data isolation (default `local`)
- `AUTH_APIGENE_SECRET_KEY` — auto-generated on setup; change for production
- `NEXT_PUBLIC_SERVER_BASE_URL` — only needed for custom domain/LAN/HTTPS

## Conventions

- **CLI:** Bash scripts in `lib/`; main entrypoint is `./apigene`
- **Auth default:** `NEXT_PUBLIC_AUTH_PROVIDER=apigene` (API key). Supported values: `apigene | keycloak | clerk`
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
