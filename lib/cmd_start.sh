#!/usr/bin/env bash

cmd_start() {
  local pull_images=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pull) pull_images=true ;;
      -h|--help)
        apigene_banner "Apigene Start"
        echo "Usage: apigene start [--pull]"
        echo ""
        echo "  apigene start        Start all services"
        echo "  apigene start --pull Pull images, then start"
        echo "                       Local name:tag images are left on the machine"
        return 0
        ;;
      *)
        apigene_err "Unknown option: $1"
        return 1
        ;;
    esac
    shift
  done

  apigene_require_env
  apigene_load_env

  apigene_banner "Apigene Start"
  apigene_info "Base URL:   ${C_BOLD}${APIGENE_BASE_URL}${C_RESET}"
  apigene_print_images
  apigene_info "Time:       $(date '+%Y-%m-%d %H:%M:%S')"

  apigene_runtime_init || return 1

  if [[ "$pull_images" == "true" ]]; then
    apigene_section "Pull images"
    apigene_pull_images
  fi

  apigene_section "Start services"
  apigene_step "${APIGENE_COMPOSE[*]} up -d"
  apigene_compose up -d
  apigene_ok "Containers started"

  apigene_section "Endpoints"
  apigene_info "UI + API:  ${C_BOLD}${APIGENE_BASE_URL}${C_RESET}"
  apigene_info "Health:    ${APIGENE_BASE_URL}/nginx-health"
  apigene_info "API:       ${APIGENE_BASE_URL}/api/health"
  apigene_info "Docs:      ${APIGENE_BASE_URL}/docs"

  echo ""
  apigene_warn "First boot may take 1–2 minutes for all services to become healthy."
  echo ""
  apigene_info "Verify:  ${C_BOLD}./apigene test${C_RESET}"
  apigene_info "Logs:    ${C_DIM}./apigene logs${C_RESET}"
  apigene_info "Stop:    ${C_BOLD}./apigene stop${C_RESET}"
  echo ""
  echo -e "${C_GREEN}${C_BOLD}✔ Apigene is starting.${C_RESET}"
}
