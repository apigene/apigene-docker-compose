#!/usr/bin/env bash
# Shared defaults for the Apigene CLI and installer.
# Set APIGENE_PORT once in .env; everything else derives from it.

APIGENE_DEFAULT_PORT="${APIGENE_DEFAULT_PORT:-8080}"

apigene_public_base_url() {
  local port="${1:-${APIGENE_PORT:-${APIGENE_DEFAULT_PORT}}}"
  echo "http://localhost:${port}"
}

# Read the first uncommented KEY=value from .env (ignores parent-shell exports).
apigene_env_file_value() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 1
  grep -E "^[[:space:]]*${key}=" "$file" | head -1 | cut -d= -f2- \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '"'"'"
}

# Resolve the public base URL for CLI output and health checks.
apigene_resolve_base_url() {
  local port="${1:-${APIGENE_DEFAULT_PORT}}"
  local explicit="${2:-}"
  local url

  if [[ -n "$explicit" ]]; then
    url="$explicit"
  else
    url="$(apigene_public_base_url "$port")"
  fi

  # Older .env templates used http://localhost while nginx listens on APIGENE_PORT.
  if [[ "$url" =~ ^https?://localhost/?$ ]]; then
    url="http://localhost:${port}"
  fi

  echo "$url"
}
