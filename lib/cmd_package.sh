#!/usr/bin/env bash
# Build the on-prem release bundle. No registry upload.

APIGENE_PACKAGE_STAGE=""
APIGENE_PACKAGE_PARTIAL=""

olgene_package_cleanup() {
  if [[ -n "${APIGENE_PACKAGE_STAGE}" && -d "${APIGENE_PACKAGE_STAGE}" ]]; then
    rm -rf "${APIGENE_PACKAGE_STAGE}"
  fi
  if [[ -n "${APIGENE_PACKAGE_PARTIAL}" && -f "${APIGENE_PACKAGE_PARTIAL}" ]]; then
    rm -f "${APIGENE_PACKAGE_PARTIAL}"
  fi
}

cmd_package_usage() {
  cat <<EOF
Usage: ./olgene package <tag>

  Build the on-prem bundle for a release tag (for example 5.5.1).
  Writes ol-gene-<tag>-linux-amd64.tar.gz and a .sha256 file in this directory.

The tag is the image tag on public.ecr.aws/apigene. latest is rejected.
This command pulls linux/amd64 images, writes a CycloneDX SBOM per image
under sbom/, and does not upload them. syft must be on PATH.
EOF
}

# Set an uncommented KEY=value. A commented example line is left in place.
olgene_package_env_set() {
  local file="$1" key="$2" value="$3"
  if grep -qE "^[[:space:]]*${key}=" "$file"; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' "s|^[[:space:]]*${key}=.*|${key}=${value}|" "$file"
    else
      sed -i "s|^[[:space:]]*${key}=.*|${key}=${value}|" "$file"
    fi
    return 0
  fi
  printf '%s=%s\n' "$key" "$value" >> "$file"
}

olgene_package_sha256() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return 0
  fi
  shasum -a 256 "$file" | awk '{print $1}'
}

# sbom/apigene-backend.cdx.json from public.ecr.aws/apigene/apigene-backend:5.5.1.
# sbom/mongo.cdx.json from docker.io/library/mongo:7.
olgene_package_sbom_basename() {
  local image="$1" base
  base="${image##*/}"
  base="${base%%:*}"
  printf '%s\n' "$base"
}

# Write one CycloneDX document per image that images save just pulled.
# A new process lists the refs so this shell's EXIT trap is not inherited.
olgene_package_write_sboms() {
  local stage="$1"
  local listfile scheme image base out
  listfile="${APIGENE_PACKAGE_STAGE}/image-refs.txt"
  mkdir -p "${stage}/sbom"

  bash -c '
    set -euo pipefail
    cd "$1"
    # shellcheck disable=SC1091
    source lib/ui.sh
    source lib/cmd_images.sh
    olgene_load_env
    olgene_stack_image_list
  ' bash "$stage" > "$listfile"

  olgene_runtime_init || return 1
  scheme="docker"
  [[ "${OLGENE_RUNTIME}" == "podman" ]] && scheme="podman"

  while IFS= read -r image || [[ -n "$image" ]]; do
    [[ -z "$image" ]] && continue
    base="$(olgene_package_sbom_basename "$image")"
    out="${stage}/sbom/${base}.cdx.json"
    olgene_step "syft ${image}"
    syft "${scheme}:${image}" -o "cyclonedx-json=${out}" || return 1
    if ! grep -q '"bomFormat"[[:space:]]*:[[:space:]]*"CycloneDX"' "$out"; then
      olgene_err "SBOM is not CycloneDX: ${out}"
      return 1
    fi
  done < "$listfile"

  rm -f "$listfile"
}

cmd_package() {
  local tag=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        olgene_banner "OL-Gene Package"
        cmd_package_usage
        return 0
        ;;
      -*)
        olgene_err "Unknown option: $1"
        echo ""
        cmd_package_usage
        return 1
        ;;
      *)
        if [[ -n "$tag" ]]; then
          olgene_err "Unexpected argument: $1"
          echo ""
          cmd_package_usage
          return 1
        fi
        tag="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$tag" || "$tag" == "latest" ]]; then
    olgene_err "Package requires a release tag (for example 5.5.1)"
    echo ""
    cmd_package_usage
    return 1
  fi
  if [[ ! "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    olgene_err "Tag must be a version like 5.5.1 (got: ${tag})"
    return 1
  fi
  if [[ ! -f "${APIGENE_ROOT}/INSTALL.md" ]]; then
    olgene_err "INSTALL.md is missing"
    return 1
  fi
  if ! command -v syft >/dev/null 2>&1; then
    olgene_err "syft is required to write the CycloneDX SBOM"
    olgene_info "Install Syft and re-run ./olgene package ${tag:-<tag>}"
    return 1
  fi

  local name="ol-gene-${tag}"
  local out="${APIGENE_ROOT}/${name}-linux-amd64.tar.gz"
  local checksum="${out}.sha256"
  APIGENE_PACKAGE_STAGE="$(mktemp -d)"
  APIGENE_PACKAGE_PARTIAL="${out}.partial"
  trap olgene_package_cleanup EXIT

  local stage="${APIGENE_PACKAGE_STAGE}/${name}"
  mkdir -p "${stage}/nginx"

  cp "${APIGENE_ROOT}/olgene" "$stage/olgene"
  chmod +x "$stage/olgene"
  cp -R "${APIGENE_ROOT}/lib" "$stage/lib"
  cp \
    "${APIGENE_ROOT}/docker-compose.yml" \
    "${APIGENE_ROOT}/docker-compose.logs.yml" \
    "${APIGENE_ROOT}/nginx.conf" \
    "${APIGENE_ROOT}/mongod.conf" \
    "${APIGENE_ROOT}/.env.example" \
    "$stage/"
  cp -R "${APIGENE_ROOT}/nginx/." "$stage/nginx/"

  cp "${APIGENE_ROOT}/.env.example" "$stage/.env"
  olgene_package_env_set "$stage/.env" APIGENE_IMAGE_REGISTRY "public.ecr.aws/apigene/"
  olgene_package_env_set "$stage/.env" APIGENE_IMAGE_TAG "$tag"
  olgene_package_env_set "$stage/.env" APIGENE_IMAGE_PLATFORM "linux/amd64"
  olgene_package_env_set "$stage/.env" DEPLOYMENT_TYPE "OnPrem"
  olgene_package_env_set "$stage/.env" NEXT_PUBLIC_AUTH_PROVIDER "apigene"
  olgene_package_env_set "$stage/.env" AUTH_APIGENE_SECRET_KEY "YOUR_SECRET_KEY"

  sed "s/__OL_GENE_VERSION__/${tag}/g" "${APIGENE_ROOT}/INSTALL.md" > "$stage/INSTALL.md"

  olgene_banner "OL-Gene Package"
  olgene_info "Version:  ${tag}"
  olgene_info "Stage:    ${stage}"

  olgene_section "Save images"
  # The copy cd's to its own directory. A subshell here would inherit the
  # EXIT trap and delete the stage on bash versions that run it.
  "$stage/olgene" images save olgene-images.tar.gz || return 1

  olgene_section "Write SBOM"
  olgene_package_write_sboms "$stage" || return 1

  olgene_section "Write archive"
  tar -C "$APIGENE_PACKAGE_STAGE" -czf "$APIGENE_PACKAGE_PARTIAL" "$name"
  mv "$APIGENE_PACKAGE_PARTIAL" "$out"
  APIGENE_PACKAGE_PARTIAL=""

  local digest
  digest="$(olgene_package_sha256 "$out")"
  printf '%s  %s\n' "$digest" "$(basename "$out")" > "$checksum"

  olgene_ok "Wrote ${out}"
  olgene_ok "Wrote ${checksum}"
}
