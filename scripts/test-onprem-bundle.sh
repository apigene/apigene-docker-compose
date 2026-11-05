#!/usr/bin/env bash
# Install a just-built on-prem bundle the way a customer does, and run
# ./apigene test. Publish only after this exits 0.
#
#   ./scripts/test-onprem-bundle.sh 5.5.1
#
# Reads ol-gene-<tag>-linux-amd64.tar.gz and the matching .sha256 from the
# current directory.

set -euo pipefail

tag="${1:-}"
if [[ -z "$tag" ]]; then
  echo "Usage: ./scripts/test-onprem-bundle.sh <tag>" >&2
  exit 1
fi
if [[ ! "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Tag must be a version like 5.5.1 (got: ${tag})" >&2
  exit 1
fi

archive="ol-gene-${tag}-linux-amd64.tar.gz"
checksum="${archive}.sha256"
if [[ ! -f "$archive" || ! -f "$checksum" ]]; then
  echo "Missing ${archive} or ${checksum} in $(pwd)" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c "$checksum"
else
  shasum -a 256 -c "$checksum"
fi

unpack_root="$(mktemp -d)"
install_dir="${unpack_root}/ol-gene-${tag}"
started=0

cleanup() {
  if [[ "${started:-0}" -eq 1 && -n "${install_dir:-}" && -x "${install_dir}/apigene" ]]; then
    (
      trap - EXIT
      cd "$install_dir"
      ./apigene stop
    ) || true
  fi
  if [[ -n "${unpack_root:-}" && -d "$unpack_root" ]]; then
    rm -rf "$unpack_root"
  fi
}
trap cleanup EXIT

dump_logs() {
  if [[ ! -x "${install_dir}/apigene" ]]; then
    return 0
  fi
  (
    trap - EXIT
    cd "$install_dir"
    docker compose logs --tail=200
  ) || true
}

require_line() {
  local file="$1" line="$2"
  if ! grep -qx "$line" "$file"; then
    echo "Missing exact line in ${file}: ${line}" >&2
    exit 1
  fi
}

tar -xzf "$archive" -C "$unpack_root"

if [[ ! -d "$install_dir" ]]; then
  echo "Archive did not contain ${install_dir##*/}/" >&2
  exit 1
fi

for required in apigene docker-compose.yml nginx.conf mongod.conf .env.example .env INSTALL.md apigene-images.tar.gz; do
  if [[ ! -e "${install_dir}/${required}" ]]; then
    echo "Bundle is missing ${required}" >&2
    exit 1
  fi
done

require_line "${install_dir}/.env" "APIGENE_IMAGE_TAG=${tag}"
require_line "${install_dir}/.env" "DEPLOYMENT_TYPE=OnPrem"
require_line "${install_dir}/.env" "AUTH_APIGENE_SECRET_KEY=YOUR_SECRET_KEY"
require_line "${install_dir}/.env" "NEXT_PUBLIC_AUTH_PROVIDER=apigene"

if grep -q '__OL_GENE_VERSION__' "${install_dir}/INSTALL.md"; then
  echo "INSTALL.md still contains the version placeholder" >&2
  exit 1
fi
if ! grep -q "$tag" "${install_dir}/INSTALL.md"; then
  echo "INSTALL.md does not mention ${tag}" >&2
  exit 1
fi

sbom_files=(
  apigene-backend.cdx.json
  apigene-copilot.cdx.json
  apigene-mcp-gw.cdx.json
  apigene-nginx.cdx.json
  mongo.cdx.json
  redis.cdx.json
)
for sbom_name in "${sbom_files[@]}"; do
  sbom_path="${install_dir}/sbom/${sbom_name}"
  if [[ ! -f "$sbom_path" ]]; then
    echo "Bundle is missing sbom/${sbom_name}" >&2
    exit 1
  fi
  if ! grep -q '"bomFormat"[[:space:]]*:[[:space:]]*"CycloneDX"' "$sbom_path"; then
    echo "sbom/${sbom_name} is not CycloneDX" >&2
    exit 1
  fi
done

# Isolate this boot from any other Compose project. Compose rejects dots in
# the project name, so 5.5.1 becomes olgenebundle551.
export COMPOSE_PROJECT_NAME="olgenebundle${tag//./}"

started=1
(
  trap - EXIT
  cd "$install_dir"
  ./apigene setup
)

port="$(grep -E '^[[:space:]]*APIGENE_PORT=' "${install_dir}/.env" | head -1 | cut -d= -f2- | tr -d '"'"'" || true)"
port="${port:-8080}"

echo "Waiting for nginx healthy, Celery ready, and HTTP health..."
ready=0
for i in $(seq 1 90); do
  nginx_id="$(
    trap - EXIT
    cd "$install_dir"
    docker compose ps -q nginx 2>/dev/null || true
  )"
  nginx_health="missing"
  if [[ -n "$nginx_id" ]]; then
    nginx_health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$nginx_id" 2>/dev/null || echo missing)"
  fi

  celery_ready=0
  worker_id="$(
    trap - EXIT
    cd "$install_dir"
    docker compose ps -q backend-worker 2>/dev/null || true
  )"
  if [[ -n "$worker_id" ]] && docker logs "$worker_id" 2>&1 | grep -qE 'celery@.* ready'; then
    celery_ready=1
  fi

  api_ok=0
  if curl -fsS "http://localhost:${port}/nginx-health" >/dev/null 2>&1 \
    && curl -fsS "http://localhost:${port}/api/health" 2>/dev/null | grep -q '"status"'; then
    api_ok=1
  fi

  if [[ "$nginx_health" == "healthy" && "$celery_ready" -eq 1 && "$api_ok" -eq 1 ]]; then
    echo "Stack ready after attempt ${i}"
    ready=1
    break
  fi
  echo "attempt ${i}/90 — nginx=${nginx_health} celery_ready=${celery_ready} api_ok=${api_ok}"
  sleep 5
done

if [[ "$ready" -ne 1 ]]; then
  echo "Stack did not become healthy" >&2
  dump_logs
  exit 1
fi

if ! (
  trap - EXIT
  cd "$install_dir"
  ./apigene test
); then
  dump_logs
  exit 1
fi

echo "Bundle ${archive} installed and passed ./apigene test"
