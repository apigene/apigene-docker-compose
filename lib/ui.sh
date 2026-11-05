#!/usr/bin/env bash
# Shared UI helpers for the Apigene CLI.

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/defaults.sh"

apigene_init_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[0;33m'
    C_BLUE='\033[0;34m'
    C_CYAN='\033[0;36m'
    C_MAGENTA='\033[0;35m'
  else
    C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW=''
    C_BLUE='' C_CYAN='' C_MAGENTA=''
  fi
}

apigene_banner() {
  local title="$1"
  echo -e "${C_BOLD}${C_MAGENTA}"
  echo "  ╔══════════════════════════════════════╗"
  printf "  ║ %-36s ║\n" "$title"
  echo "  ╚══════════════════════════════════════╝"
  echo -e "${C_RESET}"
}

apigene_section() {
  echo ""
  echo -e "${C_BOLD}${C_CYAN}━━ $1 ━━${C_RESET}"
}

apigene_info() {
  echo -e "  ${C_DIM}·${C_RESET}  $1"
}

apigene_ok() {
  echo -e "  ${C_GREEN}✔${C_RESET}  $1"
}

apigene_warn() {
  echo -e "  ${C_YELLOW}!${C_RESET}  $1"
}

apigene_err() {
  echo -e "  ${C_RED}✘${C_RESET}  $1"
}

apigene_step() {
  echo -e "  ${C_BLUE}→${C_RESET}  $1"
}

apigene_load_env() {
  APIGENE_PORT="${APIGENE_DEFAULT_PORT}"
  APIGENE_IMAGE_TAG="${APIGENE_DEFAULT_IMAGE_TAG}"
  APIGENE_IMAGE_REGISTRY=""
  APIGENE_BACKEND_IMAGE_TAG=""
  APIGENE_COPILOT_IMAGE_TAG=""
  APIGENE_MCP_GW_IMAGE_TAG=""
  APIGENE_NGINX_IMAGE_TAG=""
  APIGENE_BACKEND_IMAGE_NAME=""
  APIGENE_COPILOT_IMAGE_NAME=""
  APIGENE_MCP_GW_IMAGE_NAME=""
  APIGENE_NGINX_IMAGE_NAME=""
  local explicit_base_url="" registry_set=0

  if [[ -f .env ]]; then
    explicit_base_url="$(apigene_env_file_value .env NEXT_PUBLIC_SERVER_BASE_URL || true)"
    APIGENE_PORT="$(apigene_env_file_value .env APIGENE_PORT || true)"
    APIGENE_IMAGE_TAG="$(apigene_env_file_value .env APIGENE_IMAGE_TAG || true)"
    APIGENE_BACKEND_IMAGE_TAG="$(apigene_env_file_value .env APIGENE_BACKEND_IMAGE_TAG || true)"
    APIGENE_COPILOT_IMAGE_TAG="$(apigene_env_file_value .env APIGENE_COPILOT_IMAGE_TAG || true)"
    APIGENE_MCP_GW_IMAGE_TAG="$(apigene_env_file_value .env APIGENE_MCP_GW_IMAGE_TAG || true)"
    APIGENE_NGINX_IMAGE_TAG="$(apigene_env_file_value .env APIGENE_NGINX_IMAGE_TAG || true)"
    APIGENE_BACKEND_IMAGE_NAME="$(apigene_env_file_value .env APIGENE_BACKEND_IMAGE_NAME || true)"
    APIGENE_COPILOT_IMAGE_NAME="$(apigene_env_file_value .env APIGENE_COPILOT_IMAGE_NAME || true)"
    APIGENE_MCP_GW_IMAGE_NAME="$(apigene_env_file_value .env APIGENE_MCP_GW_IMAGE_NAME || true)"
    APIGENE_NGINX_IMAGE_NAME="$(apigene_env_file_value .env APIGENE_NGINX_IMAGE_NAME || true)"
    # An explicit empty registry means local name:tag images. A missing key does not.
    if apigene_env_file_has_key .env APIGENE_IMAGE_REGISTRY; then
      registry_set=1
    fi

    # shellcheck disable=SC1091
    set -a
    source .env
    set +a
  fi

  APIGENE_PORT="${APIGENE_PORT:-${APIGENE_DEFAULT_PORT}}"
  APIGENE_BASE_URL="$(apigene_resolve_base_url "${APIGENE_PORT}" "${explicit_base_url}")"
  APIGENE_IMAGE_TAG="${APIGENE_IMAGE_TAG:-${APIGENE_DEFAULT_IMAGE_TAG}}"
  APIGENE_BACKEND_IMAGE_TAG="${APIGENE_BACKEND_IMAGE_TAG:-${APIGENE_IMAGE_TAG}}"
  APIGENE_COPILOT_IMAGE_TAG="${APIGENE_COPILOT_IMAGE_TAG:-${APIGENE_IMAGE_TAG}}"
  APIGENE_MCP_GW_IMAGE_TAG="${APIGENE_MCP_GW_IMAGE_TAG:-${APIGENE_IMAGE_TAG}}"
  APIGENE_NGINX_IMAGE_TAG="${APIGENE_NGINX_IMAGE_TAG:-${APIGENE_IMAGE_TAG}}"
  APIGENE_BACKEND_IMAGE_NAME="${APIGENE_BACKEND_IMAGE_NAME:-${APIGENE_DEFAULT_BACKEND_IMAGE_NAME}}"
  APIGENE_COPILOT_IMAGE_NAME="${APIGENE_COPILOT_IMAGE_NAME:-${APIGENE_DEFAULT_COPILOT_IMAGE_NAME}}"
  APIGENE_MCP_GW_IMAGE_NAME="${APIGENE_MCP_GW_IMAGE_NAME:-${APIGENE_DEFAULT_MCP_GW_IMAGE_NAME}}"
  APIGENE_NGINX_IMAGE_NAME="${APIGENE_NGINX_IMAGE_NAME:-${APIGENE_DEFAULT_NGINX_IMAGE_NAME}}"
  if [[ "$registry_set" -eq 0 ]]; then
    APIGENE_IMAGE_REGISTRY="${APIGENE_DEFAULT_IMAGE_REGISTRY}"
  fi
  APIGENE_IMAGE_REGISTRY="$(apigene_normalize_image_registry "${APIGENE_IMAGE_REGISTRY}")"
  APIGENE_BACKEND_IMAGE="$(apigene_join_image "${APIGENE_IMAGE_REGISTRY}" "${APIGENE_BACKEND_IMAGE_NAME}" "${APIGENE_BACKEND_IMAGE_TAG}")"
  APIGENE_COPILOT_IMAGE="$(apigene_join_image "${APIGENE_IMAGE_REGISTRY}" "${APIGENE_COPILOT_IMAGE_NAME}" "${APIGENE_COPILOT_IMAGE_TAG}")"
  APIGENE_MCP_GW_IMAGE="$(apigene_join_image "${APIGENE_IMAGE_REGISTRY}" "${APIGENE_MCP_GW_IMAGE_NAME}" "${APIGENE_MCP_GW_IMAGE_TAG}")"
  APIGENE_NGINX_IMAGE="$(apigene_join_image "${APIGENE_IMAGE_REGISTRY}" "${APIGENE_NGINX_IMAGE_NAME}" "${APIGENE_NGINX_IMAGE_TAG}")"
  # Compose interpolation is single-level so podman-compose 1.0.3 can parse it.
  # Export the resolved pieces and the port-derived public URL for that step.
  # APIGENE_IMAGE_REGISTRY uses ${VAR-default} in the compose file: empty stays
  # empty, and a missing key falls back to public ECR.
  export APIGENE_IMAGE_TAG APIGENE_IMAGE_REGISTRY \
    APIGENE_BACKEND_IMAGE_TAG APIGENE_COPILOT_IMAGE_TAG \
    APIGENE_MCP_GW_IMAGE_TAG APIGENE_NGINX_IMAGE_TAG \
    APIGENE_BACKEND_IMAGE_NAME APIGENE_COPILOT_IMAGE_NAME \
    APIGENE_MCP_GW_IMAGE_NAME APIGENE_NGINX_IMAGE_NAME \
    APIGENE_BACKEND_IMAGE APIGENE_COPILOT_IMAGE \
    APIGENE_MCP_GW_IMAGE APIGENE_NGINX_IMAGE
  if [[ -z "${NEXT_PUBLIC_SERVER_BASE_URL:-}" ]]; then
    export NEXT_PUBLIC_SERVER_BASE_URL="${APIGENE_BASE_URL}"
  fi
  if [[ -z "${ALLOWED_ORIGINS:-}" ]]; then
    export ALLOWED_ORIGINS="${NEXT_PUBLIC_SERVER_BASE_URL}"
  fi
  if declare -F apigene_configure_compose_files >/dev/null 2>&1; then
    apigene_configure_compose_files
  fi
}

apigene_print_images() {
  if [[ -n "${APIGENE_IMAGE_REGISTRY}" ]]; then
    apigene_info "Registry:  ${APIGENE_IMAGE_REGISTRY}"
  else
    apigene_info "Registry:  local images"
  fi
  apigene_info "backend:   ${APIGENE_BACKEND_IMAGE}"
  apigene_info "copilot:   ${APIGENE_COPILOT_IMAGE}"
  apigene_info "mcp-gw:    ${APIGENE_MCP_GW_IMAGE}"
  apigene_info "nginx:     ${APIGENE_NGINX_IMAGE}"
}

# Literal `image:` under a service. Skips values that still contain a compose substitution.
apigene_literal_service_image() {
  local service="$1" image
  image="$(awk -v svc="$service" '
    $0 ~ "^  " svc ":$" { found=1; next }
    found && /^  [^[:space:]]/ { exit }
    found && $1 == "image:" { print $2; exit }
  ' docker-compose.yml)"
  image="${image#\"}"
  image="${image%\"}"
  image="${image#\'}"
  image="${image%\'}"
  if [[ -z "$image" || "$image" == *'${'* ]]; then
    apigene_err "No literal image for ${service} in docker-compose.yml"
    return 1
  fi
  printf '%s\n' "$image"
}

# Pull remote images. name:tag references stay on the machine.
# podman-compose 1.0.3 accepts `pull` with no service names. A name list is
# "unrecognized arguments" and the command exits 2.
apigene_pull_images() {
  local -a services=(mongo redis)
  local -a local_images=()
  local -a remote_refs=()
  local spec image service line ref

  apigene_runtime_init || return 1

  for spec in \
    "backend|${APIGENE_BACKEND_IMAGE}" \
    "copilot|${APIGENE_COPILOT_IMAGE}" \
    "mcp-gw|${APIGENE_MCP_GW_IMAGE}" \
    "nginx|${APIGENE_NGINX_IMAGE}"
  do
    service="${spec%%|*}"
    image="${spec#*|}"
    if apigene_image_is_local "$image"; then
      local_images+=("${service}  ${image}")
      continue
    fi
    remote_refs+=("$image")
    services+=("$service")
    if [[ "$service" == "backend" ]]; then
      services+=(backend-worker)
    fi
  done

  if [[ ${#local_images[@]} -gt 0 ]]; then
    apigene_info "Local images — leaving these on the machine:"
    for line in "${local_images[@]}"; do
      apigene_info "  ${line}"
    done
  fi

  if [[ ${#remote_refs[@]} -eq 0 ]]; then
    apigene_step "Pulling mongo and redis"
  else
    apigene_step "Pulling images"
  fi

  if apigene_compose_is_podman_compose_v1; then
    if [[ ${#local_images[@]} -eq 0 ]]; then
      apigene_compose pull
    else
      # A bare pull also fetches name:tag images, so pull the remote refs directly.
      apigene_ctr pull "$(apigene_literal_service_image mongo)"
      apigene_ctr pull "$(apigene_literal_service_image redis)"
      if [[ ${#remote_refs[@]} -gt 0 ]]; then
        for ref in "${remote_refs[@]}"; do
          apigene_ctr pull "$ref"
        done
      fi
    fi
  else
    # pull_policy: never would make a plain `compose pull` succeed without
    # fetching anything. --policy always is the explicit pull.
    apigene_compose pull --policy always "${services[@]}"
  fi
  apigene_ok "Images up to date"
}

apigene_require_env() {
  if [[ ! -f .env ]]; then
    apigene_err ".env not found"
    apigene_info "Bundle:   ${C_BOLD}./apigene setup${C_RESET}"
    apigene_info "Registry: ${C_BOLD}./apigene setup --pull${C_RESET}"
    exit 1
  fi
}

apigene_init_colors
