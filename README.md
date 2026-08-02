# Apigene Docker Compose

Run the full [Apigene](https://apigene.ai) platform locally or on-prem with Docker. One URL serves the web UI, API, docs, and MCP gateway. MongoDB and Redis are included.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine + Compose v2)
- Docker **must be running** before you install or start the stack
- First boot downloads container images and can take several minutes
- **Windows:** use [WSL2](https://learn.microsoft.com/windows/wsl/install) with Docker Desktop’s WSL backend; run the installer inside Ubuntu/WSL, not PowerShell or CMD

## Quick start

### One-line install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/apigene/apigene-docker-compose/main/install.sh | bash
```

This clones the repo to **`~/apigene`**, creates `.env`, generates an auth secret, pulls images, and starts the stack.

When it finishes, open **http://localhost:8080** (or your `APIGENE_PORT`).

Optional environment variables for the installer:

| Variable | Default | Description |
|----------|---------|-------------|
| `APIGENE_INSTALL_DIR` | `~/apigene` | Where to clone the repo |
| `APIGENE_BRANCH` | `main` | Git branch to install |
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

## CLI reference

```bash
./apigene setup              # First-time: create .env, pull images, start
./apigene start              # Start all services
./apigene start --pull       # Pull latest images, then start
./apigene test               # Run health checks on the full stack
./apigene logs               # Tail colored logs
./apigene logs backend       # Tail a specific service
./apigene logs --raw         # Plain docker compose output
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

By default, `APIGENE_IMAGE_TAG=latest` in `.env.example` — `./apigene start --pull` fetches the current public ECR release.

```bash
./apigene start --pull
```

For production, pin a specific release in `.env` (e.g. `APIGENE_IMAGE_TAG=5.4.0`). To override one service, uncomment its per-image tag in `.env.example`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Docker not running | Start Docker Desktop, then re-run `./apigene setup` or `./apigene start` |
| `.env` missing | Run `./apigene setup` |
| Backend unhealthy | Check `./apigene logs backend` — confirm MongoDB/Redis are healthy; wait 1–2 min on first boot |
| UI loads but API fails | Ensure the URL in your browser matches `NEXT_PUBLIC_SERVER_BASE_URL` (or derived `http://localhost:$APIGENE_PORT`) |
| MCP tools fail with ECONNREFUSED | Restart mcp-gw — `APIGENE_URL` is set automatically to `http://nginx` |
| Port already in use | Change `APIGENE_PORT` in `.env` and restart |
| Compass shows wrong database | Another MongoDB may be using port 27017 — set `MONGO_HOST_PORT=27018` |
| Slow on Apple Silicon | Expected — images run via amd64 emulation |
| Install dir already exists | Remove `~/apigene` or set `APIGENE_INSTALL_DIR` to another path |

Run `./apigene test` for a full diagnostic report.

## Support

- Documentation: [apigene.ai/docs](https://docs.apigene.ai/)
- Issues: [GitHub Issues](https://github.com/apigene/apigene-docker-compose/issues)
