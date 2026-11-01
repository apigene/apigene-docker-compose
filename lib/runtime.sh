#!/usr/bin/env bash
# Container engine for the Apigene CLI.
#
# Docker Compose v2 is the only compose implementation. Podman 4.7+ runs that
# same binary through `podman compose`, which points DOCKER_HOST at the Podman
# API. An already-set DOCKER_HOST is kept so CI can force the rootful socket.
#
# Keep this detection in step with the prerequisite check in install.sh.

APIGENE_RUNTIME=""
APIGENE_COMPOSE=()
APIGENE_CTR=()

apigene_podman_socket_hint() {
  local rootless_sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
  apigene_info "Install Docker Compose v2. 'podman compose' runs the docker-compose provider."
  apigene_info "Rootless socket: systemctl --user enable --now podman.socket (${rootless_sock})"
  apigene_info "Rootful socket:  systemctl enable --now podman.socket (/run/podman/podman.sock)"
}

# True when the Docker-compatible API this CLI is talking to is Podman.
apigene_server_is_podman() {
  local platform name
  platform="$(docker version --format '{{.Server.Platform.Name}}' 2>/dev/null || true)"
  name="$(docker info --format '{{.Name}}' 2>/dev/null || true)"
  [[ "$platform" == *[Pp]odman* || "$name" == *[Pp]odman* ]]
}

apigene_runtime_init() {
  if [[ -n "${APIGENE_RUNTIME:-}" ]]; then
    return 0
  fi

  # Honor an explicit socket. The docker CLI follows DOCKER_HOST; the podman
  # CLI does not, so exec/inspect must use docker when that variable is set.
  if [[ -n "${DOCKER_HOST:-}" ]]; then
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
      APIGENE_COMPOSE=(docker compose)
      APIGENE_CTR=(docker)
      if docker info >/dev/null 2>&1 && apigene_server_is_podman; then
        APIGENE_RUNTIME=podman
      else
        APIGENE_RUNTIME=docker
      fi
      return 0
    fi
    if command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
      APIGENE_RUNTIME=podman
      APIGENE_COMPOSE=(podman compose)
      APIGENE_CTR=(podman)
      return 0
    fi
    apigene_err "DOCKER_HOST is set but neither 'docker compose' nor 'podman compose' is available."
    apigene_podman_socket_hint
    return 1
  fi

  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 && ! apigene_server_is_podman; then
    if docker compose version >/dev/null 2>&1; then
      APIGENE_RUNTIME=docker
      APIGENE_COMPOSE=(docker compose)
      APIGENE_CTR=(docker)
      return 0
    fi
    apigene_err "Docker is running but 'docker compose' is not available. Install Docker Compose v2."
    return 1
  fi

  if command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    if podman compose version >/dev/null 2>&1; then
      APIGENE_RUNTIME=podman
      APIGENE_COMPOSE=(podman compose)
      APIGENE_CTR=(podman)
      return 0
    fi
    apigene_err "Podman is running but 'podman compose' failed. Install Docker Compose v2."
    apigene_podman_socket_hint
    return 1
  fi

  apigene_err "No container engine is running. Start Docker, or start Podman and its API socket."
  apigene_podman_socket_hint
  return 1
}

# podman-compose 1.0.x accepts `ps -q` but ignores the service name, and it
# rejects `ps --status` / `ps --format`. Both engines label containers with
# com.docker.compose.service, so that filter is the fallback.
apigene_compose_is_podman_compose_v1() {
  local ver
  [[ "${APIGENE_COMPOSE_FLAVOR:-}" == "podman-compose-1" ]] && return 0
  [[ "${APIGENE_COMPOSE_FLAVOR:-}" == "other" ]] && return 1
  apigene_runtime_init || return 1
  ver="$("${APIGENE_COMPOSE[@]}" version 2>/dev/null || true)"
  if [[ "$ver" == *podman-compose* && "$ver" == *1.0.* ]]; then
    APIGENE_COMPOSE_FLAVOR="podman-compose-1"
    return 0
  fi
  APIGENE_COMPOSE_FLAVOR="other"
  return 1
}

apigene_service_id() {
  local service="$1" ids count filtered
  apigene_runtime_init || return 1
  if ! apigene_compose_is_podman_compose_v1; then
    ids="$("${APIGENE_COMPOSE[@]}" ps -q "$service" 2>/dev/null || true)"
    ids="$(printf '%s\n' "$ids" | sed '/^[[:space:]]*$/d')"
    count="$(printf '%s\n' "$ids" | grep -c . || true)"
    if [[ "$count" -eq 1 ]]; then
      printf '%s\n' "$ids"
      return 0
    fi
  fi
  filtered="$(apigene_ctr ps -aq --filter "label=com.docker.compose.service=${service}" 2>/dev/null || true)"
  printf '%s\n' "$filtered" | sed '/^[[:space:]]*$/d' | head -1
}

# True when the compose log viewer should be wired in.
apigene_log_viewer_enabled() {
  local v
  v="$(printf '%s' "${APIGENE_LOG_VIEWER:-}" | tr '[:upper:]' '[:lower:]')"
  [[ "$v" == "true" || "$v" == "1" || "$v" == "yes" ]]
}

# Call after the env file is loaded. Sets COMPOSE_FILE so every compose
# invocation (start, stop, logs, test) sees the same project.
apigene_configure_compose_files() {
  if apigene_log_viewer_enabled; then
    mkdir -p .apigene
    cat > .apigene/nginx-log-viewer.conf <<'EOF'
log_format apigene_json escape=json '{"ts":"$time_iso8601","service":"nginx","line":"$status $request"}';
access_log /var/log/apigene/nginx.jsonl apigene_json;
error_log /var/log/apigene/nginx-error.log warn;
EOF
    export COMPOSE_FILE="docker-compose.yml:docker-compose.logs.yml"
  else
    export COMPOSE_FILE="docker-compose.yml"
  fi
}

apigene_compose() {
  apigene_runtime_init || return 1
  "${APIGENE_COMPOSE[@]}" "$@"
}

apigene_ctr() {
  apigene_runtime_init || return 1
  "${APIGENE_CTR[@]}" "$@"
}
