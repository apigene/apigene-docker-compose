#!/usr/bin/env bash

cmd_logs() {
  local services=(backend copilot nginx mcp-gw backend-worker)
  local raw=false
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --raw)
        raw=true
        ;;
      -h|--help)
        apigene_banner "Apigene Logs"
        echo "Usage: apigene logs [options] [services...]"
        echo ""
        echo "  apigene logs                     Tail default services (formatted)"
        echo "  apigene logs backend nginx       Tail specific services"
        echo "  apigene logs --raw               Plain docker compose output"
        echo ""
        echo "Default services: backend copilot nginx mcp-gw backend-worker"
        echo ""
        echo "Formatted output highlights:"
        echo "  · service name by container"
        echo "  · log level (INFO, WARNING, ERROR, ...)"
        echo "  · HTTP status codes (2xx green, 4xx yellow, 5xx red)"
        return 0
        ;;
      --)
        shift
        args+=("$@")
        break
        ;;
      -*)
        apigene_err "Unknown option: $1"
        return 1
        ;;
      *)
        args+=("$1")
        ;;
    esac
    shift
  done

  if [[ ${#args[@]} -gt 0 ]]; then
    services=("${args[@]}")
  fi

  apigene_section "Logs"
  apigene_info "Services: ${services[*]}"
  if [[ "$raw" == "true" ]]; then
    apigene_info "Mode: raw (no formatting)"
  else
    apigene_info "Mode: colored ${C_DIM}(use --raw for plain output)${C_RESET}"
  fi
  echo ""

  if [[ "$raw" == "true" ]]; then
    exec docker compose logs -f --tail=100 "${services[@]}"
  fi

  if command -v stdbuf >/dev/null 2>&1; then
    exec stdbuf -oL docker compose logs -f --tail=100 "${services[@]}" \
      | awk -f "$APIGENE_ROOT/lib/format_logs.awk"
  fi

  exec docker compose logs -f --tail=100 "${services[@]}" \
    | awk -f "$APIGENE_ROOT/lib/format_logs.awk"
}
