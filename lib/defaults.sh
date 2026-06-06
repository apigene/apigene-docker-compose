#!/usr/bin/env bash
# Shared defaults for the Apigene CLI and installer.
# Set APIGENE_PORT once in .env; everything else derives from it.

APIGENE_DEFAULT_PORT="${APIGENE_DEFAULT_PORT:-8080}"

apigene_public_base_url() {
  local port="${1:-${APIGENE_PORT:-${APIGENE_DEFAULT_PORT}}}"
  echo "http://localhost:${port}"
}
