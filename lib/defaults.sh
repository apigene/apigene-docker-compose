#!/usr/bin/env bash
# Shared defaults for the Apigene CLI and installer.
# Set APIGENE_PORT once in .env; everything else derives from it.

APIGENE_DEFAULT_PORT="${APIGENE_DEFAULT_PORT:-8080}"

# Default image tag when APIGENE_IMAGE_TAG is unset (matches .env.example and docker-compose.yml).
APIGENE_DEFAULT_IMAGE_TAG="${APIGENE_DEFAULT_IMAGE_TAG:-latest}"

# Registry prefix, including the trailing slash. Empty means name:tag on the local engine.
APIGENE_DEFAULT_IMAGE_REGISTRY="${APIGENE_DEFAULT_IMAGE_REGISTRY:-public.ecr.aws/apigene/}"

# Published image names. A per-service APIGENE_*_IMAGE_NAME overrides these.
APIGENE_DEFAULT_BACKEND_IMAGE_NAME="${APIGENE_DEFAULT_BACKEND_IMAGE_NAME:-apigene-backend}"
APIGENE_DEFAULT_COPILOT_IMAGE_NAME="${APIGENE_DEFAULT_COPILOT_IMAGE_NAME:-apigene-copilot}"
APIGENE_DEFAULT_MCP_GW_IMAGE_NAME="${APIGENE_DEFAULT_MCP_GW_IMAGE_NAME:-apigene-mcp-gw}"
APIGENE_DEFAULT_NGINX_IMAGE_NAME="${APIGENE_DEFAULT_NGINX_IMAGE_NAME:-apigene-nginx}"

# Per-service overrides fall back to APIGENE_DEFAULT_IMAGE_TAG when unset.
APIGENE_DEFAULT_BACKEND_IMAGE_TAG="${APIGENE_DEFAULT_BACKEND_IMAGE_TAG:-${APIGENE_DEFAULT_IMAGE_TAG}}"
APIGENE_DEFAULT_COPILOT_IMAGE_TAG="${APIGENE_DEFAULT_COPILOT_IMAGE_TAG:-${APIGENE_DEFAULT_IMAGE_TAG}}"
APIGENE_DEFAULT_MCP_GW_IMAGE_TAG="${APIGENE_DEFAULT_MCP_GW_IMAGE_TAG:-${APIGENE_DEFAULT_IMAGE_TAG}}"
APIGENE_DEFAULT_NGINX_IMAGE_TAG="${APIGENE_DEFAULT_NGINX_IMAGE_TAG:-${APIGENE_DEFAULT_IMAGE_TAG}}"

# True when .env contains an uncommented KEY= line.
apigene_env_file_has_key() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 1
  grep -qE "^[[:space:]]*${key}=" "$file"
}

# Keep a non-empty registry usable as a prefix. Empty stays empty (local images).
apigene_normalize_image_registry() {
  local registry="${1:-}"
  registry="${registry#"${registry%%[![:space:]]*}"}"
  registry="${registry%"${registry##*[![:space:]]}"}"
  if [[ -z "$registry" ]]; then
    printf '\n'
    return 0
  fi
  registry="${registry%/}/"
  printf '%s\n' "$registry"
}

# registry already includes a trailing slash when it is non-empty.
apigene_join_image() {
  local registry="$1" name="$2" tag="$3"
  if [[ -n "$registry" ]]; then
    printf '%s%s:%s\n' "$registry" "$name" "$tag"
  else
    printf '%s:%s\n' "$name" "$tag"
  fi
}

# A local image is name:tag. A registry reference contains a slash.
apigene_image_is_local() {
  local image="$1"
  [[ "$image" != */* && "$image" != *@* ]]
}

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

# Append KEY=value lines from .env.example that are missing from an existing .env.
# Returns 0 when at least one key was added.
apigene_merge_env_from_example() {
  local example="${1:-.env.example}" env_file="${2:-.env}"
  local line key added=0

  [[ -f "$example" && -f "$env_file" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)= ]] || continue
    key="${BASH_REMATCH[1]}"
    if grep -qE "^[[:space:]]*${key}=" "$env_file"; then
      continue
    fi
    printf '%s\n' "$line" >> "$env_file"
    added=1
  done < "$example"

  [[ "$added" -eq 1 ]]
}
