# Apigene Docker Compose

Run the full [Apigene](https://apigene.ai) platform locally or on-prem with Docker. One URL serves the web UI, API, docs, and MCP gateway. MongoDB and Redis are included.

## Prerequisites

- A container engine that is running before you install or start the stack:
  - [Docker Desktop](https://www.docker.com/products/docker-desktop/) or Docker Engine + Compose v2
  - Linux with Podman 4.7 or newer and Docker Compose v2 ([Linux with Podman](#linux-with-podman))
- First boot downloads container images and can take several minutes
- Air-gapped hosts load an image archive first ([Air-gapped install](#air-gapped-install))
- **Windows:** use [WSL2](https://learn.microsoft.com/windows/wsl/install) with Docker Desktop’s WSL backend; run the installer inside Ubuntu/WSL, not PowerShell or CMD

## Quick start

### One-line install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/apigene/apigene-docker-compose/main/install.sh | bash
```

This downloads the stack into the current directory (no Git required), creates `.env`, generates an auth secret, pulls images, and starts the stack. The directory must be empty, or already be an Apigene install. Re-running the installer there updates the files and keeps `.env`.

When it finishes, open **http://localhost:8080** (or your `APIGENE_PORT`).

Optional environment variables for the installer:

| Variable | Default | Description |
|----------|---------|-------------|
| `APIGENE_INSTALL_DIR` | current directory | Where to unpack the stack. The directory must be empty or already an Apigene install |
| `APIGENE_BRANCH` | `main` | Branch archive to download |
| `APIGENE_LINK_CLI` | `0` | Set to `1` to symlink `apigene` into `~/.local/bin` |

### Manual install

```bash
git clone https://github.com/apigene/apigene-docker-compose.git
cd apigene-docker-compose

chmod +x apigene
./apigene setup
```

`./apigene setup` creates `.env` from `.env.example`, generates `AUTH_APIGENE_SECRET_KEY` if needed, pulls images, and starts services.

Open **http://localhost:8080** by default, or whatever port you set in `APIGENE_PORT`.

### After install

1. Wait 1–2 minutes on first boot for all services to become healthy.
2. Open the UI and **sign in** (create a local account on first visit).
3. Add an LLM provider key under **Settings → Models** before using chat or agents.
4. Copy your **API key** from **Settings → API key** if you connect MCP clients (Cursor, Claude, etc.).

Verify everything is healthy:

```bash
cd ~/apigene   # or your clone directory
./apigene test
./tests/integration.sh   # broad API integration suite
```

## Configuration

Copy `.env.example` to `.env` only if you are configuring manually — `./apigene setup` does this for you.

### Local development (default)

Set the host port once — URLs are derived as `http://localhost:$APIGENE_PORT`:

```bash
APIGENE_PORT=8080

DATABASE_ENV=local
CACHE_ENABLED=True
```

You do **not** need to set `NEXT_PUBLIC_SERVER_BASE_URL` for localhost; it is derived from `APIGENE_PORT`.

### Custom domain, LAN IP, or HTTPS

Set the URL users actually open in the browser. `ALLOWED_ORIGINS` follows automatically unless you override it (e.g. for multiple origins):

```bash
APIGENE_PORT=8080
NEXT_PUBLIC_SERVER_BASE_URL=https://apigene.example.com
```

LAN IP example:

```bash
APIGENE_PORT=8080
NEXT_PUBLIC_SERVER_BASE_URL=http://192.168.1.100:8080
```

Multiple allowed origins:

```bash
NEXT_PUBLIC_SERVER_BASE_URL=https://apigene.example.com
ALLOWED_ORIGINS=https://apigene.example.com,http://localhost:8080
```

`APIGENE_PORT` still controls which **host port** Docker publishes nginx on. Put a reverse proxy in front when using HTTPS on a custom domain.

### Container images

Each Apigene image is `registry` + `name` + `tag`. MongoDB and Redis are unchanged.

| Variable | Default | Role |
|----------|---------|------|
| `APIGENE_IMAGE_REGISTRY` | `public.ecr.aws/apigene/` | Registry prefix, including the trailing slash |
| `APIGENE_IMAGE_TAG` | `latest` | Tag for backend, copilot, mcp-gw, and nginx |
| `APIGENE_BACKEND_IMAGE_TAG` | `APIGENE_IMAGE_TAG` | Backend and the worker. They share one image |
| `APIGENE_COPILOT_IMAGE_TAG` | `APIGENE_IMAGE_TAG` | Copilot tag |
| `APIGENE_MCP_GW_IMAGE_TAG` | `APIGENE_IMAGE_TAG` | MCP gateway tag |
| `APIGENE_NGINX_IMAGE_TAG` | `APIGENE_IMAGE_TAG` | Nginx tag |
| `APIGENE_*_IMAGE_NAME` | published name | Optional name override (`apigene-backend`, `apigene-copilot`, `apigene-mcp-gw`, `apigene-nginx`) |
| `APIGENE_IMAGE_PLATFORM` | `linux/amd64` | Set `linux/arm64` for images built on Apple Silicon |

`./apigene` copies `APIGENE_IMAGE_TAG` onto any per-service tag that is unset, and adds a trailing slash when `APIGENE_IMAGE_REGISTRY` is missing one. An empty registry is kept empty.

**Public ECR, one tag for every service:**

```bash
APIGENE_IMAGE_REGISTRY=public.ecr.aws/apigene/
APIGENE_IMAGE_TAG=5.5.0
```

**Public ECR, backend 6.0.0 and the other services 5.5.0:**

```bash
APIGENE_IMAGE_REGISTRY=public.ecr.aws/apigene/
APIGENE_IMAGE_TAG=5.5.0
APIGENE_BACKEND_IMAGE_TAG=6.0.0
```

That resolves to:

| Service | Image |
|---------|-------|
| backend, backend-worker | `public.ecr.aws/apigene/apigene-backend:6.0.0` |
| copilot | `public.ecr.aws/apigene/apigene-copilot:5.5.0` |
| mcp-gw | `public.ecr.aws/apigene/apigene-mcp-gw:5.5.0` |
| nginx | `public.ecr.aws/apigene/apigene-nginx:5.5.0` |

**Images already on this machine** (for example `docker build -t apigene-backend:6.0.0 .`). Leave the registry empty and use the same tags:

```bash
APIGENE_IMAGE_REGISTRY=
APIGENE_IMAGE_TAG=5.5.0
APIGENE_BACKEND_IMAGE_TAG=6.0.0
```

Compose then uses `apigene-backend:6.0.0`, `apigene-copilot:5.5.0`, `apigene-mcp-gw:5.5.0`, and `apigene-nginx:5.5.0`. `./apigene setup` and `./apigene start --pull` still pull MongoDB and Redis, and leave those four images on the machine.

On Apple Silicon, images you build locally are `linux/arm64`. Set `APIGENE_IMAGE_PLATFORM=linux/arm64` for that install. The published ECR images are `linux/amd64`.

**Another registry** (a trailing slash is required):

```bash
APIGENE_IMAGE_REGISTRY=localhost:5000/
APIGENE_IMAGE_TAG=5.5.0
APIGENE_BACKEND_IMAGE_TAG=6.0.0
```

| Variable | When to set | Description |
|----------|-------------|-------------|
| `APIGENE_PORT` | Always (local) | Host port nginx binds to (default `8080`) |
| `NEXT_PUBLIC_SERVER_BASE_URL` | Custom URL | Public URL users open — domain, IP, or `https://` |
| `ALLOWED_ORIGINS` | Optional | CORS origins; defaults to `NEXT_PUBLIC_SERVER_BASE_URL` |
| `DATABASE_ENV` | Optional | Logical name to isolate data (default `local`) |
| `MONGO_HOST_PORT` | Optional | Host port for MongoDB (default `27017`) |
| `CACHE_ENABLED` | Optional | Enable Redis-backed caching (default `True`) |
| `AUTH_APIGENE_SECRET_KEY` | Production | Auto-generated on first `./apigene setup`; change before production |

MongoDB and Redis connection settings are applied automatically. You usually do not need to set `MONGO_DB_URL` or `REDIS_*` unless you use external databases.

### Authentication secret

`./apigene setup` generates `AUTH_APIGENE_SECRET_KEY` automatically for local installs. For production or if you set it manually:

```bash
openssl rand -hex 32
```

Paste the output into `.env` as `AUTH_APIGENE_SECRET_KEY=...`, then restart: `./apigene stop && ./apigene start`.

### Using a different local port

Change `APIGENE_PORT` only:

```bash
APIGENE_PORT=9090
```

Then restart: `./apigene stop && ./apigene start` → `http://localhost:9090`.

### Authentication

By default, copilot and mcp-gw use Apigene API key authentication. Sign in through the UI, configure LLM provider keys under **Settings → Models**, and use your API key for MCP clients.

To use Clerk OAuth instead, set in `.env`:

```bash
NEXT_PUBLIC_AUTH_PROVIDER=clerk
```

See the [Apigene docs](https://docs.apigene.ai/) for Clerk configuration when using that provider.

## Linux with Podman

Podman runs this same Compose file through Docker Compose v2. `podman compose` (Podman 4.7+) selects the `docker-compose` provider and points it at the Podman API. Install that provider as `docker-compose` on `PATH`.

Start the API socket before `./apigene setup`.

Rootless (socket `$XDG_RUNTIME_DIR/podman/podman.sock`):

```bash
loginctl enable-linger "$USER"
systemctl --user enable --now podman.socket podman-restart.service
```

Rootful (socket `/run/podman/podman.sock`):

```bash
systemctl enable --now podman.socket podman-restart.service
```

`restart: unless-stopped` brings containers back after a reboot when `podman-restart.service` is enabled. Rootless mode also needs `loginctl enable-linger`.

Published images are `linux/amd64`. On an arm64 host, install qemu user-mode emulation (`qemu-user-static`, or the distro binfmt package) so Podman can run them.

To point Compose at a specific socket, set `DOCKER_HOST` (for example `unix:///run/podman/podman.sock`).

## Air-gapped install

Build the image archive on a machine that can reach the registries. Load it on the air-gapped machine. The file is a gzip-compressed Docker archive, so a file saved by Docker loads into Podman, and a file saved by Podman loads into Docker.

On the connected machine, pin the tags in `.env`, then save. `./apigene images save` pulls `linux/amd64` unless `APIGENE_IMAGE_PLATFORM` is set, including MongoDB (`mongo:7`) and Redis (`redis:7-alpine`).

```bash
./apigene images save
```

That writes `apigene-images.tar.gz` in the current directory. Pass another path to change it: `./apigene images save /tmp/apigene-images.tar.gz`.

Copy the stack files, `.env`, and `apigene-images.tar.gz` to the air-gapped machine. Docker or Podman is already installed there. Load the archive and start without a pull:

```bash
./apigene images load
./apigene start
```

`./apigene images load /tmp/apigene-images.tar.gz` loads a file that is not in the current directory. Keep the same `APIGENE_IMAGE_REGISTRY` and tags in `.env` that were used when the archive was saved. The loaded names have to match those settings.

`./apigene setup` and `./apigene start --pull` contact the registry. On the air-gapped machine, use `./apigene images load` and `./apigene start`.

Chat needs a model endpoint this host can reach. A cloud LLM provider is unreachable from an air-gapped network.

## CLI reference

```bash
./apigene setup              # First-time: create .env, pull images, start
./apigene start              # Start all services
./apigene start --pull       # Pull images, then start (skips local name:tag images)
./apigene images save        # Pull stack images into apigene-images.tar.gz
./apigene images load        # Load apigene-images.tar.gz into Docker or Podman
./apigene test               # Run health checks on the full stack
./apigene logs               # Tail colored logs
./apigene logs backend       # Tail a specific service
./apigene logs --raw         # Plain compose output
./apigene stop               # Stop (keeps Mongo data)
./apigene stop --volumes     # Stop and delete Mongo data
```

## Connect MCP (Cursor, Claude, etc.)

MCP is available through the gateway — not on a separate port.

**URL format** (uses your `APIGENE_PORT`, default `8080`):

```
http://localhost:<APIGENE_PORT>/agent/<agent-name>/mcp
```

Example for agent `www`:

```
http://localhost:8080/agent/www/mcp
```

**Authentication:** Pass your Apigene API key in the `apigene-api-key` header. Copy it from the Apigene UI (**Settings → API key**) after signing in.

**Cursor `mcp.json` example:**

```json
{
  "mcpServers": {
    "apigene": {
      "url": "http://localhost:8080/agent/www/mcp",
      "headers": {
        "apigene-api-key": "YOUR_TOKEN_HERE"
      }
    }
  }
}
```

## Routing

| Path | Service |
|------|---------|
| `/` | copilot (UI) |
| `/api/*` | backend |
| `/docs`, `/redoc`, `/openapi.json` | backend |
| `/agent/<name>/mcp` | mcp-gw |
| `/.well-known/*` | mcp-gw |

Health endpoints (replace `<APIGENE_PORT>` with your port, default `8080`):

- `http://localhost:<APIGENE_PORT>/nginx-health`
- `http://localhost:<APIGENE_PORT>/api/health`

## Upgrading

`APIGENE_IMAGE_TAG=latest` tracks the current public ECR release. Pull and restart with:

```bash
./apigene start --pull
```

Pin a release with `APIGENE_IMAGE_TAG` (for example `5.5.0`). Set `APIGENE_BACKEND_IMAGE_TAG`, `APIGENE_COPILOT_IMAGE_TAG`, `APIGENE_MCP_GW_IMAGE_TAG`, or `APIGENE_NGINX_IMAGE_TAG` when one service should differ. See [Container images](#container-images) for a backend `6.0.0` / other services `5.5.0` example, a private registry, and images already on the machine.

An existing `.env` without `APIGENE_IMAGE_REGISTRY` keeps pulling `public.ecr.aws/apigene/`. The next `./apigene setup` adds the key from `.env.example`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Docker not running | Start Docker Desktop, then re-run `./apigene setup` or `./apigene start` |
| `.env` missing | Run `./apigene setup` |
| Backend unhealthy | Check `./apigene logs backend` — confirm MongoDB/Redis are healthy; wait 1–2 min on first boot |
| Mongo exits immediately (code 132) | The VM CPU does not expose AVX. MongoDB 7 requires it on x86_64. Set the hypervisor CPU to host passthrough, reboot, and confirm `avx` is in `grep -m1 '^flags' /proc/cpuinfo`. `./apigene test` reports this directly. |
| UI loads but API fails | Ensure the URL in your browser matches `NEXT_PUBLIC_SERVER_BASE_URL` (or derived `http://localhost:$APIGENE_PORT`) |
| MCP tools fail with ECONNREFUSED | Restart mcp-gw — `APIGENE_URL` is set automatically to `http://nginx` |
| Port already in use | Change `APIGENE_PORT` in `.env` and restart |
| Compass shows wrong database | Another MongoDB may be using port 27017 — set `MONGO_HOST_PORT=27018` |
| Slow on Apple Silicon | Published images are `linux/amd64` and run under emulation. Locally built arm64 images need `APIGENE_IMAGE_PLATFORM=linux/arm64` |
| Directory already has other files | `cd` into an empty directory and run the installer again |

Run `./apigene test` for a full diagnostic report.

## Support

- Documentation: [apigene.ai/docs](https://docs.apigene.ai/)
- Issues: [GitHub Issues](https://github.com/apigene/apigene-docker-compose/issues)
