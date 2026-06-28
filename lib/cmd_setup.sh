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
  fi

  if grep -qE '^AUTH_APIGENE_SECRET_KEY=(YOUR_SECRET_KEY)?$' .env 2>/dev/null; then
    local generated_secret
    generated_secret="$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 64)"
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' "s/^AUTH_APIGENE_SECRET_KEY=.*/AUTH_APIGENE_SECRET_KEY=${generated_secret}/" .env
    else
      sed -i "s/^AUTH_APIGENE_SECRET_KEY=.*/AUTH_APIGENE_SECRET_KEY=${generated_secret}/" .env
    fi
    apigene_ok "Generated AUTH_APIGENE_SECRET_KEY for this install"
    apigene_info "Change it in .env before production use (see README.md)"
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
