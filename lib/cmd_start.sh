#!/usr/bin/env bash

cmd_start() {
  local pull_images=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pull) pull_images=true ;;
      -h|--help)
        olgene_banner "OL-Gene Start"
        echo "Usage: apigene start [--pull]"
        echo ""
        echo "  apigene start        Start all services"
        echo "  apigene start --pull Pull images, then start"
        echo "                       Local name:tag images are left on the machine"
        return 0
        ;;
      *)
        olgene_err "Unknown option: $1"
        return 1
        ;;
    esac
    shift
  done

  olgene_require_env
  olgene_load_env

  olgene_banner "OL-Gene Start"
  olgene_info "Base URL:   ${C_BOLD}${APIGENE_BASE_URL}${C_RESET}"
  olgene_print_images
  olgene_info "Time:       $(date '+%Y-%m-%d %H:%M:%S')"

  olgene_runtime_init || return 1

  if [[ "$pull_images" == "true" ]]; then
    olgene_section "Pull images"
    olgene_pull_images
  fi

  olgene_section "Start services"
  olgene_step "${OLGENE_COMPOSE[*]} up -d"
  olgene_compose up -d
  olgene_ok "Containers started"

  olgene_section "Endpoints"
  olgene_info "UI + API:  ${C_BOLD}${APIGENE_BASE_URL}${C_RESET}"
  olgene_info "Health:    ${APIGENE_BASE_URL}/nginx-health"
  olgene_info "API:       ${APIGENE_BASE_URL}/api/health"
  olgene_info "Docs:      ${APIGENE_BASE_URL}/docs"
  if olgene_log_viewer_enabled; then
    olgene_info "Logs UI:   ${APIGENE_BASE_URL}/log-viewer"
  fi

  echo ""
  olgene_warn "First boot may take 1–2 minutes for all services to become healthy."
  echo ""
  olgene_info "Verify:  ${C_BOLD}./olgene test${C_RESET}"
  olgene_info "Logs:    ${C_DIM}./olgene logs${C_RESET}"
  olgene_info "Stop:    ${C_BOLD}./olgene stop${C_RESET}"
  echo ""
  echo -e "${C_GREEN}${C_BOLD}✔ Apigene is starting.${C_RESET}"
}
