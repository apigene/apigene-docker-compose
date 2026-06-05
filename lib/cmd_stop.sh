#!/usr/bin/env bash

cmd_stop() {
  local remove_volumes=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -v|--volumes) remove_volumes=true ;;
      -h|--help)
        apigene_banner "Apigene Stop"
        echo "Usage: apigene stop [--volumes]"
        echo ""
        echo "  apigene stop            Stop all containers (keep data)"
        echo "  apigene stop --volumes  Stop and delete Mongo data"
        return 0
        ;;
      *)
        apigene_err "Unknown option: $1"
        return 1
        ;;
    esac
    shift
  done

  apigene_load_env

  apigene_banner "Apigene Stop"
  apigene_info "Time: $(date '+%Y-%m-%d %H:%M:%S')"

  apigene_section "Running containers"
  if docker compose ps --status running -q 2>/dev/null | grep -q .; then
    docker compose ps --status running --format 'table {{.Service}}\t{{.Status}}' 2>/dev/null \
      | while IFS= read -r line; do
          [[ "$line" == SERVICE* ]] && continue
          [[ -z "$line" ]] && continue
          apigene_info "$line"
        done
  else
    apigene_warn "No running Apigene containers found"
  fi

  apigene_section "Shutdown"

  if [[ "$remove_volumes" == "true" ]]; then
    apigene_step "docker compose down -v"
    docker compose down -v
    echo ""
    echo -e "${C_YELLOW}${C_BOLD}! Apigene stopped. Mongo data volume removed.${C_RESET}"
  else
    apigene_step "docker compose down"
    docker compose down
    echo ""
    echo -e "${C_GREEN}${C_BOLD}✔ Apigene stopped. Data volumes preserved.${C_RESET}"
    apigene_info "Delete Mongo data too: ${C_BOLD}./apigene stop --volumes${C_RESET}"
  fi

  echo ""
  apigene_info "Start again: ${C_BOLD}./apigene start${C_RESET}"
}
