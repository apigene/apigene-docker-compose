#!/usr/bin/env bash
# Apigene one-line installer
#
#   curl -fsSL https://raw.githubusercontent.com/apigene/apigene-docker-compose/main/install.sh | bash
#
# Options (environment variables):
#   APIGENE_INSTALL_DIR   Install location (default: ~/apigene)
#   APIGENE_BRANCH        Git branch to install (default: main)
#   APIGENE_SKIP_SETUP    Set to 1 to clone/update only, skip ./apigene setup

set -euo pipefail

APIGENE_REPO="${APIGENE_REPO:-https://github.com/apigene/apigene-docker-compose.git}"
APIGENE_BRANCH="${APIGENE_BRANCH:-main}"
APIGENE_INSTALL_DIR="${APIGENE_INSTALL_DIR:-${HOME}/apigene}"
APIGENE_SKIP_SETUP="${APIGENE_SKIP_SETUP:-0}"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET='\033[0m'
  C_BOLD='\033[1m'
  C_DIM='\033[2m'
  C_RED='\033[0;31m'
  C_GREEN='\033[0;32m'
  C_YELLOW='\033[0;33m'
  C_CYAN='\033[0;36m'
  C_MAGENTA='\033[0;35m'
else
  C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_CYAN='' C_MAGENTA=''
fi

info()  { echo -e "  ${C_DIM}·${C_RESET}  $1"; }
ok()    { echo -e "  ${C_GREEN}✔${C_RESET}  $1"; }
warn()  { echo -e "  ${C_YELLOW}!${C_RESET}  $1"; }
err()   { echo -e "  ${C_RED}✘${C_RESET}  $1"; }
step()  { echo -e "  ${C_CYAN}→${C_RESET}  $1"; }
section() {
  echo ""
  echo -e "${C_BOLD}${C_CYAN}━━ $1 ━━${C_RESET}"
}

banner() {
  echo -e "${C_BOLD}${C_MAGENTA}"
  echo "  ╔══════════════════════════════════════╗"
  printf "  ║ %-36s ║\n" "Apigene Installer"
  echo "  ╚══════════════════════════════════════╝"
  echo -e "${C_RESET}"
}

usage() {
  cat <<EOF
Apigene installer — run the full platform locally with Docker.

One-line install:
  curl -fsSL https://raw.githubusercontent.com/apigene/apigene-docker-compose/main/install.sh | bash

Environment variables:
  APIGENE_INSTALL_DIR   Install directory (default: ~/apigene)
  APIGENE_BRANCH        Git branch (default: main)
  APIGENE_SKIP_SETUP    Set to 1 to skip ./apigene setup

After install:
  cd ~/apigene && ./apigene start
  cd ~/apigene && ./apigene test
EOF
}

require_command() {
  local name="$1"
  local hint="$2"
  if command -v "$name" >/dev/null 2>&1; then
    ok "$name available"
    return 0
  fi
  err "$name not found"
  info "$hint"
  return 1
}

check_docker_running() {
  if docker info >/dev/null 2>&1; then
    ok "Docker daemon is running"
    return 0
  fi
  err "Docker is installed but not running"
  info "Start Docker Desktop or your Docker daemon, then re-run the installer."
  return 1
}

install_repo() {
  section "Install files"

  if [[ -d "${APIGENE_INSTALL_DIR}/.git" ]]; then
    step "Updating existing install at ${APIGENE_INSTALL_DIR}"
    git -C "${APIGENE_INSTALL_DIR}" fetch origin "${APIGENE_BRANCH}"
    git -C "${APIGENE_INSTALL_DIR}" checkout "${APIGENE_BRANCH}"
    git -C "${APIGENE_INSTALL_DIR}" pull --ff-only origin "${APIGENE_BRANCH}" || true
    ok "Repository updated"
  elif [[ -d "${APIGENE_INSTALL_DIR}" ]]; then
    err "Install directory exists but is not a git repo: ${APIGENE_INSTALL_DIR}"
    info "Remove it or set APIGENE_INSTALL_DIR to a different path."
    exit 1
  else
    step "Cloning into ${APIGENE_INSTALL_DIR}"
    git clone --branch "${APIGENE_BRANCH}" --depth 1 "${APIGENE_REPO}" "${APIGENE_INSTALL_DIR}"
    ok "Repository cloned"
  fi

  chmod +x "${APIGENE_INSTALL_DIR}/apigene"
  ok "CLI ready: ${APIGENE_INSTALL_DIR}/apigene"
}

maybe_install_cli_symlink() {
  local bin_dir="${HOME}/.local/bin"
  local link_path="${bin_dir}/apigene"

  if [[ -d "${bin_dir}" || "${APIGENE_LINK_CLI:-0}" == "1" ]]; then
    mkdir -p "${bin_dir}"
    ln -sf "${APIGENE_INSTALL_DIR}/apigene" "${link_path}"
    ok "Linked CLI to ${link_path}"
    if [[ ":${PATH}:" != *":${bin_dir}:"* ]]; then
      warn "Add ${bin_dir} to your PATH to run ${C_BOLD}apigene${C_RESET} from anywhere:"
      info "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
    fi
  else
    info "Run commands from: ${C_BOLD}cd ${APIGENE_INSTALL_DIR}${C_RESET}"
    info "Or link globally:  ${C_BOLD}APIGENE_LINK_CLI=1 curl ... | bash${C_RESET}"
  fi
}

run_setup() {
  section "Setup stack"
  (
    cd "${APIGENE_INSTALL_DIR}"
    ./apigene setup
  )
}

print_next_steps() {
  local env_file="${APIGENE_INSTALL_DIR}/.env"
  section "Next steps"

  if [[ ! -f "${env_file}" ]] || ! grep -q '^OPENAI_API_KEY=.\+' "${env_file}" 2>/dev/null; then
    warn "Add your API keys to ${env_file}"
    info "Required: OPENAI_API_KEY and Clerk keys (see README.md)"
    info "Then run: ${C_BOLD}cd ${APIGENE_INSTALL_DIR} && ./apigene setup${C_RESET}"
    echo ""
  fi

  info "Start:   ${C_BOLD}cd ${APIGENE_INSTALL_DIR} && ./apigene start${C_RESET}"
  info "Test:    ${C_BOLD}cd ${APIGENE_INSTALL_DIR} && ./apigene test${C_RESET}"
  info "Open:    ${C_BOLD}http://localhost${C_RESET} (or your APIGENE_PORT / NEXT_PUBLIC_SERVER_BASE_URL)"
  info "Docs:    https://github.com/apigene/apigene-docker-compose"
  echo ""
  echo -e "${C_GREEN}${C_BOLD}✔ Install complete.${C_RESET}"
}

main() {
  case "${1:-}" in
    -h|--help|help)
      usage
      exit 0
      ;;
  esac

  banner

  section "Prerequisites"
  require_command git "Install Git: https://git-scm.com/downloads" || exit 1
  require_command docker "Install Docker Desktop: https://www.docker.com/products/docker-desktop/" || exit 1
  require_command curl "Install curl from your system package manager." || exit 1
  docker compose version >/dev/null 2>&1 \
    && ok "docker compose available ($(docker compose version --short 2>/dev/null || docker compose version | head -1))" \
    || { err "docker compose not available"; info "Install Docker Compose v2 with Docker Desktop."; exit 1; }
  check_docker_running || exit 1

  install_repo
  maybe_install_cli_symlink

  if [[ "${APIGENE_SKIP_SETUP}" != "1" ]]; then
    run_setup
  else
    warn "Skipped ./apigene setup (APIGENE_SKIP_SETUP=1)"
  fi

  print_next_steps
}

main "$@"
