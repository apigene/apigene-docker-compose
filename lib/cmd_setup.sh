#!/usr/bin/env bash

cmd_setup_usage() {
  cat <<EOF
Usage: ./olgene setup [--pull] [archive]

  ./olgene setup              Load olgene-images.tar.gz and start
  ./olgene setup <archive>    Load that archive and start
  ./olgene setup --pull       Pull images from the registry and start

Creates .env from .env.example when it is missing, and generates
AUTH_APIGENE_SECRET_KEY when it is still the placeholder.
The archive path cannot be combined with --pull.
EOF
}

cmd_setup_prepare_env() {
  if [[ -f .env ]]; then
    olgene_section "Update configuration"
    if olgene_merge_env_from_example; then
      olgene_ok "Added missing settings from .env.example"
    else
      olgene_info "Configuration up to date"
    fi
  fi

  if [[ ! -f .env ]]; then
    olgene_section "Create configuration"
    cp .env.example .env
    olgene_ok "Created .env from .env.example"
  fi

  if grep -qE '^AUTH_APIGENE_SECRET_KEY=(YOUR_SECRET_KEY)?$' .env 2>/dev/null; then
    local generated_secret
    generated_secret="$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 64)"
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' "s/^AUTH_APIGENE_SECRET_KEY=.*/AUTH_APIGENE_SECRET_KEY=${generated_secret}/" .env
    else
      sed -i "s/^AUTH_APIGENE_SECRET_KEY=.*/AUTH_APIGENE_SECRET_KEY=${generated_secret}/" .env
    fi
    olgene_ok "Generated AUTH_APIGENE_SECRET_KEY for this install"
    olgene_info "Change it in .env before production use (see README.md)"
  fi

  olgene_load_env
  olgene_info "Base URL:  ${C_BOLD}${APIGENE_BASE_URL}${C_RESET}"
}

cmd_setup() {
  local pull_images=false
  local archive=""
  local default_archive="${APIGENE_DEFAULT_IMAGE_ARCHIVE:-olgene-images.tar.gz}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        olgene_banner "OL-Gene Setup"
        cmd_setup_usage
        return 0
        ;;
      --pull)
        pull_images=true
        shift
        ;;
      -*)
        olgene_err "Unknown option: $1"
        echo ""
        cmd_setup_usage
        return 1
        ;;
      *)
        if [[ -n "$archive" ]]; then
          olgene_err "Unexpected argument: $1"
          echo ""
          cmd_setup_usage
          return 1
        fi
        archive="$1"
        shift
        ;;
    esac
  done

  if [[ "$pull_images" == true && -n "$archive" ]]; then
    olgene_err "--pull does not take an archive path"
    echo ""
    cmd_setup_usage
    return 1
  fi

  # Missing bundle fails before .env is written and before any registry contact.
  if [[ "$pull_images" != true ]]; then
    archive="${archive:-$default_archive}"
    if [[ ! -f "$archive" ]]; then
      olgene_err "Archive not found: ${archive}"
      olgene_info "Run this from the unpacked release directory, or pass the archive path."
      return 1
    fi
  fi

  olgene_banner "OL-Gene Setup"
  cmd_setup_prepare_env

  if [[ "$pull_images" == true ]]; then
    olgene_section "Pull images"
    olgene_pull_images || return 1
  else
    cmd_images_load "$archive" || return 1
  fi

  olgene_section "Start services"
  cmd_start
}
