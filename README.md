# Apigene Docker Compose

Run the full [Apigene](https://apigene.ai) platform locally or on-prem with a single command. One URL serves the web UI, API, docs, and MCP gateway. MongoDB and Redis are included.

## What you get

| Service | Role |
|---------|------|
| **nginx** | Single entry point (default port **80**) |
| **copilot** | Web UI at `/` |
| **backend** | API at `/api/*`, docs at `/docs` |
| **mcp-gw** | MCP gateway at `/agent/<name>/mcp` |
| **mongo** | Database |
| **redis** | Cache and background jobs |

All application images are pulled from public ECR — no build step required.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine + Compose v2)
- An [OpenAI API key](https://platform.openai.com/api-keys)
- A [Clerk](https://clerk.com) account for authentication

**Apple Silicon (M1/M2/M3):** Images run as `linux/amd64` via emulation. First start may take a few extra minutes.

## Quick start

```bash
git clone https://github.com/apigene/apigene-docker-compose.git
cd apigene-docker-compose

cp .env.example .env
# Edit .env — add OpenAI and Clerk keys (see Clerk setup below)

chmod +x apigene
./apigene setup
```

Open **http://localhost** (or the URL matching your `APIGENE_PORT` and `NEXT_PUBLIC_SERVER_BASE_URL`).

Verify everything is healthy:

```bash
./apigene test
```

## Clerk setup

Apigene uses [Clerk](https://clerk.com) for sign-in. You need a Clerk application with these settings:

### 1. Create a Clerk application

Go to [dashboard.clerk.com](https://dashboard.clerk.com) and create an application.

### 2. Copy API keys into `.env`

From **API Keys** in the Clerk dashboard:

| `.env` variable | Where to find it |
|-----------------|------------------|
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` | Publishable key (`pk_…`) |
| `CLERK_SECRET_KEY` | Secret key (`sk_…`) |
| `AUTH_CLERK_PUBLIC_KEY` | JWT public key (PEM format, or `base64:…` prefix) |
| `CLERK_REMOTE_API_URL` | Frontend API URL, e.g. `https://your-app.clerk.accounts.dev` |

### 3. Create a JWT template

In Clerk → **JWT Templates**, create a template (e.g. `apigene-24hr-user-token`) and set:

```
NEXT_PUBLIC_AUTH_CLERK_JWT_TPL=apigene-24hr-user-token
```

### 4. Configure allowed origins and redirects

In Clerk → **Paths** or **Domains**, add your Apigene URL:

- Allowed origin: `http://localhost` (or your custom URL/port)
- Sign-in URL: `/sign-in`
- Sign-up URL: `/sign-up`

Set the same values in `.env`:

```bash
NEXT_PUBLIC_SERVER_BASE_URL=http://localhost
ALLOWED_ORIGINS=http://localhost
```

If you use a non-default port (e.g. `8080`), include the port in all three places.

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

**URL format:**

```
http://localhost/agent/<agent-name>/mcp
```

Example for agent `www`:

```
http://localhost/agent/www/mcp
```

**Authentication:** Pass your Apigene user token in the `apigene-api-key` header. You can copy this from the Apigene UI (Settings → API key) or use a Clerk-backed JWT.

**Cursor `mcp.json` example:**

```json
{
  "mcpServers": {
    "apigene": {
      "url": "http://localhost/agent/www/mcp",
      "headers": {
        "apigene-api-key": "YOUR_TOKEN_HERE"
      }
    }
  }
}
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `APIGENE_PORT` | `80` | Host port for the web gateway |
| `APIGENE_IMAGE_TAG` | `latest` | Tag for all `public.ecr.aws/apigene/*` images |
| `MONGO_HOST_PORT` | `27017` | Host port for MongoDB (for Compass, etc.) |
| `DATABASE_ENV` | `local` | Logical name to isolate data between deployments |

### Using a different port

If port 80 is in use or requires elevated privileges:

```bash
# In .env:
APIGENE_PORT=8080
NEXT_PUBLIC_SERVER_BASE_URL=http://localhost:8080
ALLOWED_ORIGINS=http://localhost:8080
```

Then restart: `./apigene stop && ./apigene start`


## Routing

| Path | Service |
|------|---------|
| `/` | copilot (UI) |
| `/api/*` | backend |
| `/docs`, `/redoc`, `/openapi.json` | backend |
| `/agent/<name>/mcp` | mcp-gw |
| `/.well-known/*` | mcp-gw |

Health endpoints:

- http://localhost/nginx-health
- http://localhost/api/health

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
| Backend unhealthy | Check `./apigene logs backend` — confirm `OPENAI_API_KEY` and Clerk keys |
| UI loads but API fails | Ensure `NEXT_PUBLIC_SERVER_BASE_URL` matches your browser URL (including port) |
| Clerk redirect wrong port | Set `NEXT_PUBLIC_SERVER_BASE_URL` with the correct port; update Clerk allowed origins |
| MCP returns 500 / publishable key missing | Ensure `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` and `CLERK_REMOTE_API_URL` are set in `.env` |
| MCP tools fail with ECONNREFUSED | Restart mcp-gw — `APIGENE_URL` is set automatically to `http://nginx` |
| Port already in use | Change `APIGENE_PORT` and update URLs in `.env` |
| Compass shows wrong database | Another MongoDB may be using port 27017 — set `MONGO_HOST_PORT=27018` |
| Slow on Apple Silicon | Expected — images run via amd64 emulation |

Run `./apigene test` for a full diagnostic report.

## Support

- Documentation: [apigene.ai/docs](https://docs.apigene.ai/)
- Issues: [GitHub Issues](https://github.com/apigene/apigene-docker-compose/issues)
