#!/usr/bin/env bash
# Save the stack images to an archive, load that archive into Docker or Podman,
# or push the images to a private registry.
# Used to carry an on-prem install onto a machine that cannot pull images.

APIGENE_DEFAULT_IMAGE_ARCHIVE="apigene-images.tar.gz"
# Init image of the Helm chart (initImage in values.yaml). Compose does not run it.
APIGENE_INIT_IMAGE="docker.io/library/busybox:1.36"

cmd_images_usage() {
  cat <<EOF
Usage: ./apigene images <save|load> [archive]
       ./apigene images push <registry>

  ./apigene images save [archive]   Pull the stack images and write an archive
  ./apigene images load [archive]   Load an archive into Docker or Podman
  ./apigene images push <registry>  Push loaded images to a private registry

The archive defaults to ${APIGENE_DEFAULT_IMAGE_ARCHIVE} in the current directory.
Image names and tags come from .env. The file is a gzip-compressed Docker
archive, so it loads into either engine.

Save pulls ${APIGENE_IMAGE_PLATFORM:-linux/amd64} unless APIGENE_IMAGE_PLATFORM is set.
On the air-gapped machine, load the archive and run ./apigene start
without --pull.
EOF
}

# One resolved ref per line: four Apigene images, MongoDB, Redis, and the
# Helm chart's init image.
apigene_stack_image_list() {
  local image seen=""
  local mongo redis
  mongo="$(apigene_literal_service_image mongo)"
  redis="$(apigene_literal_service_image redis)"
  for image in \
    "$APIGENE_BACKEND_IMAGE" \
    "$APIGENE_COPILOT_IMAGE" \
    "$APIGENE_MCP_GW_IMAGE" \
    "$APIGENE_NGINX_IMAGE" \
    "$mongo" \
    "$redis" \
    "$APIGENE_INIT_IMAGE"
  do
    [[ " ${seen} " == *" ${image} "* ]] && continue
    seen+=" ${image}"
    printf '%s\n' "$image"
  done
}

# mongo:7 and redis:7-alpine have no registry slash, but they are published
# library images and must be pulled for the target platform.
apigene_image_is_hub_library() {
  local name="${1%%:*}"
  [[ "$name" == "mongo" || "$name" == "redis" ]]
}

apigene_platform_arch() {
  local platform="$1"
  printf '%s\n' "${platform##*/}"
}

apigene_image_arch() {
  apigene_ctr image inspect --format '{{.Architecture}}' "$1" 2>/dev/null || true
}

# Drop a trailing tag. localhost:5000/name:tag keeps the registry port.
apigene_image_repo() {
  local image="$1" last
  last="${image##*:}"
  if [[ "$image" == *:* && "$last" != */* ]]; then
    printf '%s\n' "${image%:*}"
  else
    printf '%s\n' "$image"
  fi
}

# Platform digest from a multi-arch index. Empty when the image is single-arch.
apigene_platform_digest() {
  local image="$1" platform="$2" os arch
  os="${platform%%/*}"
  arch="${platform##*/}"
  command -v python3 >/dev/null 2>&1 || return 1
  apigene_ctr manifest inspect "$image" 2>/dev/null | python3 -c '
import json, sys
os_name, arch = sys.argv[1], sys.argv[2]
try:
    doc = json.load(sys.stdin)
except json.JSONDecodeError:
    raise SystemExit(1)
for item in doc.get("manifests") or doc.get("Manifests") or []:
    plat = item.get("platform") or item.get("Platform") or {}
    if plat.get("os") == os_name and plat.get("architecture") == arch:
        digest = item.get("digest") or item.get("Digest") or ""
        if digest:
            print(digest)
            raise SystemExit(0)
raise SystemExit(1)
' "$os" "$arch"
}

# Put the previous image id back on its name after the archive is written.
# A running engine can keep another architecture under the same tag.
apigene_restore_displaced_images() {
  local entry name id
  [[ ${#APIGENE_IMAGE_RESTORE[@]} -eq 0 ]] && return 0
  for entry in "${APIGENE_IMAGE_RESTORE[@]}"; do
    name="${entry%%|*}"
    id="${entry#*|}"
    apigene_ctr tag "$id" "$name" >/dev/null || true
    apigene_ctr image rm "${name}-apigene-previous" >/dev/null || true
  done
  APIGENE_IMAGE_RESTORE=()
}

apigene_pull_image() {
  local image="$1" platform="$2" want have current_id keep
  want="$(apigene_platform_arch "$platform")"
  if apigene_image_is_local "$image" && ! apigene_image_is_hub_library "$image"; then
    if ! apigene_ctr inspect "$image" >/dev/null 2>&1; then
      apigene_err "Local image not found: ${image}"
      apigene_info "Build or tag it before saving the archive"
      return 1
    fi
    have="$(apigene_image_arch "$image")"
    if [[ -n "$have" && "$have" != "$want" ]]; then
      apigene_warn "${image} is ${have}; the archive will contain ${have}"
    fi
    apigene_info "Local image, not pulling: ${image}"
    return 0
  fi

  have="$(apigene_image_arch "$image")"
  if [[ "$have" == "$want" ]]; then
    apigene_info "Already present (${want}): ${image}"
    return 0
  fi

  apigene_step "Pulling ${image} (${platform})"
  if [[ -n "$have" ]]; then
    current_id="$(apigene_ctr image inspect --format '{{.Id}}' "$image")"
    keep="${image}-apigene-previous"
    apigene_info "Local ${image} is ${have}; pulling ${platform}"
    apigene_ctr tag "$image" "$keep"
    APIGENE_IMAGE_RESTORE+=("${image}|${current_id}")
  fi
  # A multi-arch tag inspects as the host architecture. Pull the platform
  # manifest itself and point the tag at that single image while saving.
  digest="$(apigene_platform_digest "$image" "$platform" || true)"
  if [[ -n "$digest" ]]; then
    repo="$(apigene_image_repo "$image")"
    if ! apigene_ctr pull "${repo}@${digest}"; then
      return 1
    fi
    apigene_ctr tag "${repo}@${digest}" "$image"
  elif ! apigene_ctr pull --platform "$platform" "$image"; then
    return 1
  fi
  have="$(apigene_image_arch "$image")"
  if [[ "$have" != "$want" ]]; then
    apigene_err "${image} is ${have:-missing} after pulling ${platform}"
    return 1
  fi
}

cmd_images_save() {
  local archive="${APIGENE_DEFAULT_IMAGE_ARCHIVE}"
  local platform="" image
  local -a images=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --platform)
        [[ $# -ge 2 ]] || { apigene_err "--platform requires a value"; return 1; }
        platform="$2"
        shift 2
        ;;
      -h|--help)
        apigene_banner "Apigene Images"
        cmd_images_usage
        return 0
        ;;
      -*)
        apigene_err "Unknown option: $1"
        return 1
        ;;
      *)
        archive="$1"
        shift
        ;;
    esac
  done

  apigene_load_env
  if [[ ! -f .env ]]; then
    apigene_warn "No .env — archive uses the default registry and tag"
  fi
  platform="${platform:-${APIGENE_IMAGE_PLATFORM:-linux/amd64}}"

  apigene_runtime_init || return 1
  # Bash 3.2 has no RETURN trap, so every exit after a pull restores tags.
  APIGENE_IMAGE_RESTORE=()

  while IFS= read -r image; do
    [[ -n "$image" ]] && images+=("$image")
  done < <(apigene_stack_image_list)

  apigene_banner "Apigene Images"
  apigene_print_images
  apigene_info "Platform:  ${platform}"
  apigene_info "Archive:   ${archive}"
  apigene_info "Engine:    ${APIGENE_RUNTIME}"

  apigene_section "Pull images"
  for image in "${images[@]}"; do
    if ! apigene_pull_image "$image" "$platform"; then
      apigene_restore_displaced_images
      return 1
    fi
  done
  apigene_ok "Images ready"

  apigene_section "Save archive"
  # docker load and podman load both read a gzip-compressed Docker archive.
  set -o pipefail
  if [[ "$APIGENE_RUNTIME" == "podman" ]]; then
    apigene_step "podman save --format docker-archive | gzip > ${archive}"
    if ! apigene_ctr save --format docker-archive "${images[@]}" | gzip > "$archive"; then
      apigene_restore_displaced_images
      return 1
    fi
  else
    apigene_step "docker save | gzip > ${archive}"
    if ! apigene_ctr save "${images[@]}" | gzip > "$archive"; then
      apigene_restore_displaced_images
      return 1
    fi
  fi
  apigene_restore_displaced_images
  apigene_ok "Wrote ${archive}"
  apigene_info "Copy this file and the same image settings in .env to the air-gapped machine."
  apigene_info "Load there with: ${C_BOLD}./apigene images load ${archive}${C_RESET}"
}

cmd_images_load() {
  local archive="${APIGENE_DEFAULT_IMAGE_ARCHIVE}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        apigene_banner "Apigene Images"
        cmd_images_usage
        return 0
        ;;
      -*)
        apigene_err "Unknown option: $1"
        return 1
        ;;
      *)
        archive="$1"
        shift
        ;;
    esac
  done

  if [[ ! -f "$archive" ]]; then
    apigene_err "Archive not found: ${archive}"
    return 1
  fi

  apigene_runtime_init || return 1

  apigene_banner "Apigene Images"
  apigene_info "Archive:  ${archive}"
  apigene_info "Engine:   ${APIGENE_RUNTIME}"

  apigene_section "Load archive"
  apigene_step "${APIGENE_RUNTIME} load -i ${archive}"
  apigene_ctr load -i "$archive"
  apigene_ok "Images loaded into ${APIGENE_RUNTIME}"
  apigene_info "Start without pulling: ${C_BOLD}./apigene start${C_RESET}"
}

# Publish under short names, as <registry>/mongo:7. The Helm chart's images.mirror
# value expects that layout.
cmd_images_push() {
  local registry="" image target
  local -a images=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        apigene_banner "Apigene Images"
        cmd_images_usage
        return 0
        ;;
      -*)
        apigene_err "Unknown option: $1"
        return 1
        ;;
      *)
        if [[ -n "$registry" ]]; then
          apigene_err "Unexpected argument: $1"
          return 1
        fi
        registry="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$registry" ]]; then
    apigene_err "Registry is required: ./apigene images push <registry>"
    return 1
  fi
  registry="${registry%/}"

  apigene_load_env
  if [[ ! -f .env ]]; then
    apigene_warn "No .env — using the default registry and tag"
  fi

  apigene_runtime_init || return 1

  while IFS= read -r image; do
    [[ -n "$image" ]] && images+=("$image")
  done < <(apigene_stack_image_list)

  apigene_banner "Apigene Images"
  apigene_info "Registry: ${registry}"
  apigene_info "Engine:   ${APIGENE_RUNTIME}"

  apigene_section "Check images"
  for image in "${images[@]}"; do
    if ! apigene_ctr image inspect "$image" >/dev/null 2>&1; then
      apigene_err "Image not found: ${image}"
      apigene_info "Run ./apigene images load first, with the same image settings in .env"
      return 1
    fi
  done
  apigene_ok "Images ready"

  apigene_section "Push images"
  for image in "${images[@]}"; do
    target="${registry}/${image##*/}"
    apigene_step "${image} -> ${target}"
    apigene_ctr tag "$image" "$target" || return 1
    if ! apigene_ctr push "$target"; then
      apigene_err "Push failed: ${target}"
      apigene_info "Log in first: ${APIGENE_RUNTIME} login ${registry%%/*}"
      return 1
    fi
  done
  apigene_ok "Images pushed to ${registry}"
  apigene_info "Helm: ${C_BOLD}--set images.mirror=${registry}${C_RESET}"
}

cmd_images() {
  local sub="${1:-}"

  case "$sub" in
    ""|-h|--help)
      apigene_banner "Apigene Images"
      cmd_images_usage
      if [[ -z "$sub" ]]; then
        return 1
      fi
      return 0
      ;;
    save)
      shift
      cmd_images_save "$@"
      ;;
    load)
      shift
      cmd_images_load "$@"
      ;;
    push)
      shift
      cmd_images_push "$@"
      ;;
    *)
      apigene_err "Unknown images command: $sub"
      echo ""
      cmd_images_usage
      return 1
      ;;
  esac
}
