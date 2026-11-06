#!/usr/bin/env bash
# Container engine for the OL-Gene CLI.
#
# Docker Compose v2 is the only compose implementation. Podman 4.7+ runs that
# same binary through `podman compose`, which points DOCKER_HOST at the Podman
# API. An already-set DOCKER_HOST is kept so CI can force the rootful socket.
#
# Keep this detection in step with the prerequisite check in install.sh.

OLGENE_RUNTIME=""
OLGENE_COMPOSE=()
OLGENE_CTR=()

olgene_podman_socket_hint() {
  local rootless_sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
  olgene_info "Install Docker Compose v2. 'podman compose' runs the docker-compose provider."
  olgene_info "Rootless socket: systemctl --user enable --now podman.socket (${rootless_sock})"
  olgene_info "Rootful socket:  systemctl enable --now podman.socket (/run/podman/podman.sock)"
}

# True when the Docker-compatible API this CLI is talking to is Podman.
olgene_server_is_podman() {
  local platform name
  platform="$(docker version --format '{{.Server.Platform.Name}}' 2>/dev/null || true)"
  name="$(docker info --format '{{.Name}}' 2>/dev/null || true)"
  [[ "$platform" == *[Pp]odman* || "$name" == *[Pp]odman* ]]
}

olgene_runtime_init() {
  if [[ -n "${OLGENE_RUNTIME:-}" ]]; then
    return 0
  fi

  # Honor an explicit socket. The docker CLI follows DOCKER_HOST; the podman
  # CLI does not, so exec/inspect must use docker when that variable is set.
  if [[ -n "${DOCKER_HOST:-}" ]]; then
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
      OLGENE_COMPOSE=(docker compose)
      OLGENE_CTR=(docker)
      if docker info >/dev/null 2>&1 && olgene_server_is_podman; then
        OLGENE_RUNTIME=podman
      else
        OLGENE_RUNTIME=docker
      fi
      return 0
    fi
    if command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
      OLGENE_RUNTIME=podman
      OLGENE_COMPOSE=(podman compose)
      OLGENE_CTR=(podman)
      return 0
    fi
    olgene_err "DOCKER_HOST is set but neither 'docker compose' nor 'podman compose' is available."
    olgene_podman_socket_hint
    return 1
  fi

  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 && ! olgene_server_is_podman; then
    if docker compose version >/dev/null 2>&1; then
      OLGENE_RUNTIME=docker
      OLGENE_COMPOSE=(docker compose)
      OLGENE_CTR=(docker)
      return 0
    fi
    olgene_err "Docker is running but 'docker compose' is not available. Install Docker Compose v2."
    return 1
  fi

  if command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    if podman compose version >/dev/null 2>&1; then
      OLGENE_RUNTIME=podman
      OLGENE_COMPOSE=(podman compose)
      OLGENE_CTR=(podman)
      return 0
    fi
    olgene_err "Podman is running but 'podman compose' failed. Install Docker Compose v2."
    olgene_podman_socket_hint
    return 1
  fi

  olgene_err "No container engine is running. Start Docker, or start Podman and its API socket."
  olgene_podman_socket_hint
  return 1
}

# podman-compose 1.0.x accepts `ps -q` but ignores the service name, and it
# rejects `ps --status` / `ps --format`. Both engines label containers with
# com.docker.compose.service, so that filter is the fallback.
olgene_compose_is_podman_compose_v1() {
  local ver
  [[ "${OLGENE_COMPOSE_FLAVOR:-}" == "podman-compose-1" ]] && return 0
  [[ "${OLGENE_COMPOSE_FLAVOR:-}" == "other" ]] && return 1
  olgene_runtime_init || return 1
  ver="$("${OLGENE_COMPOSE[@]}" version 2>/dev/null || true)"
  if [[ "$ver" == *podman-compose* && "$ver" == *1.0.* ]]; then
    OLGENE_COMPOSE_FLAVOR="podman-compose-1"
    return 0
  fi
  OLGENE_COMPOSE_FLAVOR="other"
  return 1
}

olgene_service_id() {
  local service="$1" ids count filtered
  olgene_runtime_init || return 1
  if ! olgene_compose_is_podman_compose_v1; then
    ids="$("${OLGENE_COMPOSE[@]}" ps -q "$service" 2>/dev/null || true)"
    ids="$(printf '%s\n' "$ids" | sed '/^[[:space:]]*$/d')"
    count="$(printf '%s\n' "$ids" | grep -c . || true)"
    if [[ "$count" -eq 1 ]]; then
      printf '%s\n' "$ids"
      return 0
    fi
  fi
  filtered="$(olgene_ctr ps -aq --filter "label=com.docker.compose.service=${service}" 2>/dev/null || true)"
  printf '%s\n' "$filtered" | sed '/^[[:space:]]*$/d' | head -1
}

# True when the compose log viewer should be wired in.
olgene_log_viewer_enabled() {
  local v
  v="$(printf '%s' "${LOG_VIEWER:-}" | tr '[:upper:]' '[:lower:]')"
  [[ "$v" == "true" || "$v" == "1" || "$v" == "yes" ]]
}

# Call after the env file is loaded. Sets COMPOSE_FILE so every compose
# invocation (start, stop, logs, test) sees the same project.
olgene_configure_compose_files() {
  if olgene_log_viewer_enabled; then
    mkdir -p .olgene
    cat > .olgene/nginx-log-viewer.conf <<'EOF'
log_format olgene_json escape=json '{"ts":"$time_iso8601","service":"nginx","line":"$status $request"}';
access_log /var/log/olgene/nginx.jsonl olgene_json;
error_log /var/log/olgene/nginx-error.log warn;
EOF
    export COMPOSE_FILE="docker-compose.yml:docker-compose.logs.yml"
  else
    export COMPOSE_FILE="docker-compose.yml"
  fi
}

olgene_compose() {
  olgene_runtime_init || return 1
  "${OLGENE_COMPOSE[@]}" "$@"
}

olgene_ctr() {
  olgene_runtime_init || return 1
  "${OLGENE_CTR[@]}" "$@"
}
