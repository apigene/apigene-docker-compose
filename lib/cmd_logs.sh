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
        olgene_banner "OL-Gene Logs"
        echo "Usage: ./olgene logs [options] [services...]"
        echo ""
        echo "  ./olgene logs                     Tail default services (formatted)"
        echo "  ./olgene logs backend nginx       Tail specific services"
        echo "  ./olgene logs --raw               Plain compose output"
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
        olgene_err "Unknown option: $1"
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

  olgene_section "Logs"
  olgene_info "Services: ${services[*]}"
  if [[ "$raw" == "true" ]]; then
    olgene_info "Mode: raw (no formatting)"
  else
    olgene_info "Mode: colored ${C_DIM}(use --raw for plain output)${C_RESET}"
  fi
  echo ""

  olgene_runtime_init || return 1

  if [[ "$raw" == "true" ]]; then
    exec "${OLGENE_COMPOSE[@]}" logs -f --tail=100 "${services[@]}"
  fi

  if command -v stdbuf >/dev/null 2>&1; then
    exec stdbuf -oL "${OLGENE_COMPOSE[@]}" logs -f --tail=100 "${services[@]}" \
      | awk -f "$APIGENE_ROOT/lib/format_logs.awk"
  fi

  exec "${OLGENE_COMPOSE[@]}" logs -f --tail=100 "${services[@]}" \
    | awk -f "$APIGENE_ROOT/lib/format_logs.awk"
}
