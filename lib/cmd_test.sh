#!/usr/bin/env bash

cmd_test() {
  local PORT BASE_URL IMAGE_TAG
  local SERVICES REQUIRED_ENV_KEYS
  local PASS=0 FAIL=0 WARN=0 START_TS

  PORT="${APIGENE_PORT:-${APIGENE_DEFAULT_PORT}}"
  BASE_URL="${NEXT_PUBLIC_SERVER_BASE_URL:-$(apigene_public_base_url "${PORT}")}"
  IMAGE_TAG="${APIGENE_IMAGE_TAG:-latest}"

  if [[ -f .env ]]; then
    apigene_load_env
    PORT="${APIGENE_PORT}"
    BASE_URL="${APIGENE_BASE_URL}"
    IMAGE_TAG="${APIGENE_IMAGE_TAG}"
  fi

  SERVICES=(mongo redis backend backend-worker copilot mcp-gw nginx)
  REQUIRED_ENV_KEYS=(
    OPENAI_API_KEY
    AUTH_CLERK_PUBLIC_KEY
    CLERK_SECRET_KEY
    NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
    NEXT_PUBLIC_AUTH_CLERK_JWT_TPL
    CLERK_REMOTE_API_URL
  )
  START_TS="$(date +%s)"

  pass() { apigene_ok "$1"; PASS=$((PASS + 1)); }
  fail() { apigene_err "$1"; FAIL=$((FAIL + 1)); }
  warn() { apigene_warn "$1"; WARN=$((WARN + 1)); }
  info() { apigene_info "$1"; }
  section() { apigene_section "$1"; }

  container_id() {
    docker compose ps -q "$1" 2>/dev/null || true
  }

  check_container_running() {
    local service="$1" id state started
    id="$(container_id "$service")"
    if [[ -z "$id" ]]; then
      fail "$service — container not found (is the stack running?)"
      return
    fi
    state="$(docker inspect -f '{{.State.Status}}' "$id")"
    started="$(docker inspect -f '{{.State.StartedAt}}' "$id")"
    if [[ "$state" == "running" ]]; then
      pass "$service — running (since ${started})"
    else
      fail "$service — state is '$state' (expected running)"
    fi
  }

  check_container_healthy() {
    local service="$1" id health
    id="$(container_id "$service")"
    if [[ -z "$id" ]]; then
      fail "$service — health check skipped (container missing)"
      return
    fi
    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$id")"
    case "$health" in
      healthy) pass "$service — Docker health: healthy" ;;
      none) info "$service — no Docker healthcheck defined" ;;
      *) fail "$service — Docker health: $health" ;;
    esac
  }

  check_http_json() {
    local name="$1" url="$2" expected_re="$3"
    local body ms code
    body="$(curl -fsS --max-time 15 -w $'\n__HTTP_CODE__:%{http_code}\n__TIME__:%{time_total}' "$url" 2>/dev/null || true)"
    code="$(echo "$body" | sed -n 's/^__HTTP_CODE__://p')"
    ms="$(echo "$body" | sed -n 's/^__TIME__://p' | awk '{printf "%.0f", $1 * 1000}')"
    body="$(echo "$body" | sed '/^__HTTP_CODE__:/d;/^__TIME__:/d')"
    if [[ "$body" =~ $expected_re ]]; then
      pass "$name — OK (${ms}ms) ${C_DIM}${url}${C_RESET}"
    else
      fail "$name — unexpected response ${C_DIM}(HTTP ${code:-?}, ${ms}ms)${C_RESET}: ${body:-<empty>}"
    fi
  }

  check_http_status() {
    local name="$1" url="$2" expected_codes="$3" code ms
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$url" || true)"
    ms="$(curl -s -o /dev/null -w '%{time_total}' --max-time 15 "$url" 2>/dev/null | awk '{printf "%.0f", $1 * 1000}' || true)"
    if [[ " $expected_codes " == *" $code "* ]]; then
      pass "$name — HTTP $code (${ms}ms) ${C_DIM}${url}${C_RESET}"
    else
      fail "$name — HTTP $code (${ms}ms), expected one of:$expected_codes ${C_DIM}${url}${C_RESET}"
    fi
  }

  check_http_header() {
    local name="$1" url="$2" header="$3" expected_re="$4" value
    value="$(curl -s -I --max-time 15 "$url" 2>/dev/null | awk -v h="$header" 'tolower($1) == tolower(h ":") {print $2}' | tr -d '\r' | head -1)"
    if [[ "$value" =~ $expected_re ]]; then
      pass "$name — ${header}: ${value}"
    else
      fail "$name — ${header} missing or unexpected (got: ${value:-<none>})"
    fi
  }

  check_tcp_from_container() {
    local cid="$1" label="$2" host="$3" port="$4"
    if [[ -z "$cid" ]]; then
      fail "$label — container missing"
      return
    fi
    if docker exec "$cid" sh -c "
      if command -v python >/dev/null 2>&1; then
        python -c \"import socket; s=socket.create_connection(('$host', $port), 3); s.close()\"
      elif command -v nc >/dev/null 2>&1; then
        nc -z '$host' '$port'
      elif command -v wget >/dev/null 2>&1; then
        wget -q -O /dev/null --timeout=3 'http://$host:$port/'
      else
        cat < /dev/null > /dev/tcp/$host/$port
      fi
    " >/dev/null 2>&1; then
      pass "$label — TCP $host:$port reachable"
    else
      fail "$label — TCP $host:$port unreachable"
    fi
  }

  apigene_banner "Apigene Test"
  info "Base URL:   ${C_BOLD}${BASE_URL}${C_RESET}"
  info "Image tag:  ${IMAGE_TAG}"
  info "Project:    $(basename "$PWD")"
  info "Time:       $(date '+%Y-%m-%d %H:%M:%S')"

  section "Prerequisites"
  command -v docker >/dev/null 2>&1 && pass "docker CLI available ($(docker --version | head -1))" || fail "docker CLI not found"
  docker compose version >/dev/null 2>&1 && pass "docker compose available ($(docker compose version --short 2>/dev/null || docker compose version | head -1))" || fail "docker compose not available"
  command -v curl >/dev/null 2>&1 && pass "curl available" || fail "curl not found"
  [[ -f .env ]] && pass ".env file present" || warn ".env file missing — run: ./apigene setup"

  section "Configuration"
  curl -fsS --max-time 5 "${BASE_URL}/nginx-health" >/dev/null 2>&1 \
    && pass "Host entry point reachable at ${BASE_URL}" \
    || fail "Cannot reach ${BASE_URL} — is APIGENE_PORT correct and nginx running?"

  if [[ -f .env ]]; then
    for key in "${REQUIRED_ENV_KEYS[@]}"; do
      [[ -n "${!key:-}" ]] && pass ".env has ${key}" || warn ".env missing ${key} — some features may not work"
    done
    [[ "${NEXT_PUBLIC_SERVER_BASE_URL:-}" == "${BASE_URL}" ]] \
      && pass "NEXT_PUBLIC_SERVER_BASE_URL matches test base URL" \
      || warn "NEXT_PUBLIC_SERVER_BASE_URL (${NEXT_PUBLIC_SERVER_BASE_URL:-<unset>}) differs from ${BASE_URL}"
  fi

  local backend_id redis_host mongo_url tenant_name copilot_id public_url mcp_gw_id apigene_url clerk_pk
  backend_id="$(container_id backend)"
  if [[ -n "$backend_id" ]]; then
    redis_host="$(docker exec "$backend_id" printenv REDIS_HOST 2>/dev/null || true)"
    mongo_url="$(docker exec "$backend_id" printenv MONGO_DB_URL 2>/dev/null || true)"
    tenant_name="$(docker exec "$backend_id" printenv TENANT_NAME 2>/dev/null || true)"
    [[ "$redis_host" == "redis" ]] && pass "backend REDIS_HOST=redis" || fail "backend REDIS_HOST='${redis_host:-<unset>}' (expected redis)"
    [[ "$mongo_url" == *"mongo:27017"* ]] && pass "backend MONGO_DB_URL points at bundled mongo" || fail "backend MONGO_DB_URL unexpected: ${mongo_url:-<unset>}"
    [[ -n "$tenant_name" ]] && pass "backend TENANT_NAME=${tenant_name}" || warn "backend TENANT_NAME is unset"
  fi

  copilot_id="$(container_id copilot)"
  if [[ -n "$copilot_id" ]]; then
    public_url="$(docker exec "$copilot_id" printenv NEXT_PUBLIC_SERVER_BASE_URL 2>/dev/null || true)"
    [[ -n "$public_url" ]] && pass "copilot NEXT_PUBLIC_SERVER_BASE_URL=${public_url}" || warn "copilot NEXT_PUBLIC_SERVER_BASE_URL unset"
  fi

  mcp_gw_id="$(container_id mcp-gw)"
  if [[ -n "$mcp_gw_id" ]]; then
    apigene_url="$(docker exec "$mcp_gw_id" printenv APIGENE_URL 2>/dev/null || true)"
    clerk_pk="$(docker exec "$mcp_gw_id" printenv CLERK_PUBLISHABLE_KEY 2>/dev/null || true)"
    [[ "$apigene_url" == "http://nginx" ]] && pass "mcp-gw APIGENE_URL=http://nginx" || fail "mcp-gw APIGENE_URL='${apigene_url:-<unset>}' (expected http://nginx)"
    [[ -n "$clerk_pk" ]] && pass "mcp-gw CLERK_PUBLISHABLE_KEY is set" || warn "mcp-gw CLERK_PUBLISHABLE_KEY unset — MCP auth may fail"
  fi

  section "Containers"
  for service in "${SERVICES[@]}"; do check_container_running "$service"; done

  section "Docker healthchecks"
  for service in mongo redis backend nginx; do check_container_healthy "$service"; done

  section "Data stores"
  local redis_id mongo_id
  redis_id="$(container_id redis)"
  mongo_id="$(container_id mongo)"
  [[ -n "$redis_id" ]] && docker exec "$redis_id" redis-cli ping 2>/dev/null | grep -q PONG && pass "redis — responds to PING" || fail "redis — PING failed"
  [[ -n "$mongo_id" ]] && docker exec "$mongo_id" mongosh --quiet --eval 'db.runCommand({ ping: 1 }).ok' 2>/dev/null | grep -q 1 && pass "mongo — responds to ping" || fail "mongo — ping failed"
  docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q 'apigene_mongo_data' && pass "mongo data volume exists (apigene_mongo_data)" || warn "mongo data volume apigene_mongo_data not found"

  section "Service connectivity"
  local nginx_id worker_id
  nginx_id="$(container_id nginx)"
  mcp_gw_id="$(container_id mcp-gw)"
  worker_id="$(container_id backend-worker)"
  check_tcp_from_container "$backend_id" "backend → redis" "redis" 6379
  check_tcp_from_container "$backend_id" "backend → mongo" "mongo" 27017
  check_tcp_from_container "$nginx_id" "nginx → backend" "backend" 8000
  check_tcp_from_container "$nginx_id" "nginx → mcp-gw" "mcp-gw" 8001

  [[ -n "$backend_id" ]] && docker exec "$backend_id" python -c \
    "import urllib.request; r=urllib.request.urlopen('http://127.0.0.1:8000/api/health', timeout=5); assert b'ok' in r.read()" 2>/dev/null \
    && pass "backend — direct /api/health on :8000" || fail "backend — direct /api/health on :8000 failed"

  [[ -n "$backend_id" ]] && docker exec "$backend_id" python -c \
    "import os; from pymongo import MongoClient; MongoClient(os.environ['MONGO_DB_URL'], serverSelectionTimeoutMS=5000).admin.command('ping')" 2>/dev/null \
    && pass "backend — MongoDB driver connection" || fail "backend — MongoDB driver connection failed"

  [[ -n "$worker_id" ]] && docker logs "$worker_id" 2>&1 | grep -q 'celery@.* ready' \
    && pass "backend-worker — Celery worker ready" || fail "backend-worker — Celery worker not ready (check logs)"

  [[ -n "$nginx_id" ]] && docker exec "$nginx_id" sh -c \
    'wget -q -S -O /dev/null http://127.0.0.1:3000/ 2>&1 | grep -q "HTTP/"' \
    && pass "copilot — reachable at 127.0.0.1:3000 from nginx network" || fail "copilot — not reachable at 127.0.0.1:3000 from nginx network"

  [[ -n "$mcp_gw_id" ]] && docker exec "$mcp_gw_id" sh -c \
    'wget -q -S -O /dev/null http://127.0.0.1:8001/ 2>&1 | grep -q "HTTP/"' \
    && pass "mcp-gw — listening on :8001" || fail "mcp-gw — not listening on :8001"

  [[ -n "$copilot_id" ]] && docker exec "$copilot_id" node -e \
    "require('http').get('http://localhost/api/health',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>{if(!d.includes('ok'))process.exit(1)})}).on('error',()=>process.exit(1))" 2>/dev/null \
    && pass "copilot — server-side fetch to http://localhost/api/health" || fail "copilot — server-side fetch to http://localhost/api/health failed"

  section "Gateway & public routes"
  check_http_json "nginx health" "${BASE_URL}/nginx-health" '"service"[[:space:]]*:[[:space:]]*"nginx"'
  check_http_json "backend health" "${BASE_URL}/api/health" '"status"[[:space:]]*:[[:space:]]*"ok"'
  check_http_status "OpenAPI schema" "${BASE_URL}/openapi.json" "200 401 403"
  check_http_status "API docs (Swagger)" "${BASE_URL}/docs" "200 401 403"
  check_http_status "API docs (ReDoc)" "${BASE_URL}/redoc" "200 401 403 404"
  check_http_status "Copilot UI (root)" "${BASE_URL}/" "200 301 302 307 308 404"
  check_http_status "Copilot sign-in" "${BASE_URL}/sign-in" "200 301 302 307 308"
  check_http_status "MCP OAuth callback route" "${BASE_URL}/mcp_gw_oauth_callback" "200 301 302 307 308 400 404 405 500"
  check_http_header "Clerk middleware active" "${BASE_URL}/" "x-clerk-auth-status" '.*'

  local ELAPSED=$(( $(date +%s) - START_TS ))
  echo ""
  echo -e "${C_BOLD}━━ Summary ━━${C_RESET}"
  echo -e "  ${C_GREEN}Passed:${C_RESET}  ${PASS}"
  echo -e "  ${C_RED}Failed:${C_RESET}  ${FAIL}"
  echo -e "  ${C_YELLOW}Warnings:${C_RESET} ${WARN}"
  echo -e "  ${C_DIM}Duration: ${ELAPSED}s${C_RESET}"
  echo ""

  if [[ "$FAIL" -gt 0 ]]; then
    echo -e "${C_RED}${C_BOLD}✘ Some checks failed.${C_RESET}"
    apigene_info "Debug: ${C_BOLD}./apigene logs${C_RESET}"
    return 1
  fi

  if [[ "$WARN" -gt 0 ]]; then
    echo -e "${C_YELLOW}${C_BOLD}! All critical checks passed with warnings.${C_RESET}"
  else
    echo -e "${C_GREEN}${C_BOLD}✔ All checks passed.${C_RESET}"
  fi
  return 0
}
