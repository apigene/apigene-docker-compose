#!/usr/bin/env bash

cmd_stop() {
  local remove_volumes=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -v|--volumes) remove_volumes=true ;;
      -h|--help)
        olgene_banner "OL-Gene Stop"
        echo "Usage: apigene stop [--volumes]"
        echo ""
        echo "  apigene stop            Stop all containers (keep data)"
        echo "  apigene stop --volumes  Stop and delete Mongo data"
        return 0
        ;;
      *)
        olgene_err "Unknown option: $1"
        return 1
        ;;
    esac
    shift
  done

  olgene_load_env

  olgene_banner "OL-Gene Stop"
  olgene_info "Time: $(date '+%Y-%m-%d %H:%M:%S')"

  olgene_runtime_init || return 1

  olgene_section "Running containers"
  if ! olgene_compose_is_podman_compose_v1 \
    && olgene_compose ps --status running -q >/dev/null 2>&1 \
    && olgene_compose ps --status running -q 2>/dev/null | grep -q .; then
    olgene_compose ps --status running --format 'table {{.Service}}\t{{.Status}}' 2>/dev/null \
      | while IFS= read -r line; do
          [[ "$line" == SERVICE* ]] && continue
          [[ -z "$line" ]] && continue
          olgene_info "$line"
        done
  elif olgene_ctr ps --filter label=com.docker.compose.service --format '{{.Names}} {{.Status}}' 2>/dev/null \
      | grep -q .; then
    olgene_ctr ps --filter label=com.docker.compose.service --format '{{.Names}} {{.Status}}' 2>/dev/null \
      | while IFS= read -r line; do
          [[ -z "$line" ]] && continue
          olgene_info "$line"
        done
  else
    olgene_warn "No running Apigene containers found"
  fi

  olgene_section "Shutdown"

  if [[ "$remove_volumes" == "true" ]]; then
    olgene_step "${OLGENE_COMPOSE[*]} down -v"
    olgene_compose down -v
    echo ""
    echo -e "${C_YELLOW}${C_BOLD}! Apigene stopped. Mongo data volume removed.${C_RESET}"
  else
    olgene_step "${OLGENE_COMPOSE[*]} down"
    olgene_compose down
    echo ""
    echo -e "${C_GREEN}${C_BOLD}✔ Apigene stopped. Data volumes preserved.${C_RESET}"
    olgene_info "Delete Mongo data too: ${C_BOLD}./olgene stop --volumes${C_RESET}"
  fi

  echo ""
  olgene_info "Start again: ${C_BOLD}./olgene start${C_RESET}"
}
