#!/usr/bin/env bash

cmd_setup() {
  apigene_banner "Apigene Setup"

  if [[ -f .env ]]; then
    apigene_section "Update configuration"
    if apigene_merge_env_from_example; then
      apigene_ok "Added missing settings from .env.example"
    else
      apigene_info "Configuration up to date"
    fi
  fi

  if [[ ! -f .env ]]; then
    apigene_section "Create configuration"
    cp .env.example .env
    apigene_ok "Created .env from .env.example"
    echo ""
    apigene_warn "Edit .env and set AUTH_APIGENE_SECRET_KEY (see README.md)"
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
