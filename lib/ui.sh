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
  APIGENE_IMAGE_TAG="latest"
  local explicit_base_url=""

  if [[ -f .env ]]; then
    explicit_base_url="$(apigene_env_file_value .env NEXT_PUBLIC_SERVER_BASE_URL || true)"
    APIGENE_PORT="$(apigene_env_file_value .env APIGENE_PORT || true)"
    APIGENE_IMAGE_TAG="$(apigene_env_file_value .env APIGENE_IMAGE_TAG || true)"

    # shellcheck disable=SC1091
    set -a
    source .env
    set +a
  fi

  APIGENE_PORT="${APIGENE_PORT:-${APIGENE_DEFAULT_PORT}}"
  APIGENE_BASE_URL="$(apigene_resolve_base_url "${APIGENE_PORT}" "${explicit_base_url}")"
  APIGENE_IMAGE_TAG="${APIGENE_IMAGE_TAG:-latest}"
}

apigene_require_env() {
  if [[ ! -f .env ]]; then
    apigene_err ".env not found"
    apigene_info "First-time setup: ${C_BOLD}./apigene setup${C_RESET}"
    exit 1
  fi
}

apigene_init_colors
