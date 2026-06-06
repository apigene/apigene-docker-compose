#!/usr/bin/env bash

cmd_setup() {
  apigene_banner "Apigene Setup"

  if [[ ! -f .env ]]; then
    apigene_section "Create configuration"
    cp .env.example .env
    apigene_ok "Created .env from .env.example"
    echo ""
    apigene_warn "Edit .env and add your API keys (OpenAI, etc.)"
    apigene_info "See README.md for configuration."
    apigene_info "Then run: ${C_BOLD}./apigene setup${C_RESET}"
    return 0
  fi

  apigene_load_env
  apigene_info "Base URL:  ${C_BOLD}${APIGENE_BASE_URL}${C_RESET}"

  apigene_section "Pull images"
  apigene_step "Pulling from public ECR..."
  docker compose pull
  apigene_ok "Images ready"

  apigene_section "Start services"
  cmd_start
}
