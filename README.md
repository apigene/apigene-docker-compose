# Apigene Docker Compose

Run the full [Apigene](https://apigene.ai) platform locally or on-prem with a single command. One URL serves the web UI, API, docs, and MCP gateway. MongoDB and Redis are included.

## Quick start

### One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/apigene/apigene-docker-compose/main/install.sh | bash
```
## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine + Compose v2)
- An [OpenAI API key](https://platform.openai.com/api-keys)


### Manual install

```bash
git clone https://github.com/apigene/apigene-docker-compose.git
cd apigene-docker-compose

cp .env.example .env
# Edit .env — add your OpenAI API keys (see Configuration below)

chmod +x apigene
./apigene setup
```

Open **http://localhost:8080** by default, or whatever port you set in `APIGENE_PORT`.

Verify everything is healthy:

```bash
./apigene test
```

## Configuration

Copy `.env.example` to `.env` and fill in the required values.

### Local development (default)

Set the host port once — URLs are derived as `http://localhost:$APIGENE_PORT`:

```bash
APIGENE_PORT=8080

OPENAI_API_KEY=
DEFAULT_OPEN_API_KEY=
DATABASE_ENV=local
CACHE_ENABLED=True
```

### Custom domain, LAN IP, or HTTPS

Set the URL users actually open in the browser. `ALLOWED_ORIGINS` follows automatically unless you override it (e.g. for multiple origins):

```bash
APIGENE_PORT=8080
NEXT_PUBLIC_SERVER_BASE_URL=https://apigene.example.com

OPENAI_API_KEY=
DEFAULT_OPEN_API_KEY=
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

MongoDB and Redis connection settings are applied automatically. You usually do not need to set `MONGO_DB_URL` or `REDIS_*` unless you use external databases.

### Using a different local port

Change `APIGENE_PORT` only:

```bash
APIGENE_PORT=9090
```

Then restart: `./apigene stop && ./apigene start` → `http://localhost:9090`.

### Authentication

By default, copilot and mcp-gw use Apigene API key authentication. Sign in through the UI and use your API key for MCP clients.

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

**Authentication:** Pass your Apigene API key in the `apigene-api-key` header. Copy it from the Apigene UI (Settings → API key).

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

Pull the latest images and restart:

```bash
./apigene start --pull
```

To pin a specific version, set `APIGENE_IMAGE_TAG` in `.env`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `.env` missing | Run `./apigene setup` |
| Backend unhealthy | Check `./apigene logs backend` — confirm `OPENAI_API_KEY` is set |
| UI loads but API fails | Ensure the URL in your browser matches `NEXT_PUBLIC_SERVER_BASE_URL` (or derived `http://localhost:$APIGENE_PORT`) |
| MCP tools fail with ECONNREFUSED | Restart mcp-gw — `APIGENE_URL` is set automatically to `http://nginx` |
| Port already in use | Change `APIGENE_PORT` in `.env` and restart |
| Compass shows wrong database | Another MongoDB may be using port 27017 — set `MONGO_HOST_PORT=27018` |
| Slow on Apple Silicon | Expected — images run via amd64 emulation |
| Redis / backend slow to start | First boot may take 1–2 minutes while health checks pass |

Run `./apigene test` for a full diagnostic report.

## Support

- Documentation: [apigene.ai/docs](https://docs.apigene.ai/)
- Issues: [GitHub Issues](https://github.com/apigene/apigene-docker-compose/issues)
