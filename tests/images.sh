#!/usr/bin/env bash
# Unit tests for ./olgene images. The container engine is stubbed, so no
# images are pulled or pushed.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/lib/ui.sh"
# shellcheck disable=SC1091
source "$ROOT/lib/runtime.sh"
# shellcheck disable=SC1091
source "$ROOT/lib/defaults.sh"
# shellcheck disable=SC1091
source "$ROOT/lib/cmd_images.sh"

PASS=0
FAIL=0
CALLS="$(mktemp)"
MISSING_IMAGE=""
FAILING_PUSH=""
trap 'rm -f "$CALLS"' EXIT

olgene_runtime_init() { OLGENE_RUNTIME=docker; }

olgene_ctr() {
  echo "$*" >> "$CALLS"
  if [[ "$1 $2" == "image inspect" && "$3" == "$MISSING_IMAGE" ]]; then
    return 1
  fi
  if [[ "$1" == "push" && "$2" == "$FAILING_PUSH" ]]; then
    return 1
  fi
}

check() {
  local name="$1"
  shift
  if "$@"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${name}" >&2
  fi
}

called() { grep -qxF "$1" "$CALLS"; }
not_called() { ! grep -q "^$1" "$CALLS"; }
reset() {
  : > "$CALLS"
  MISSING_IMAGE=""
  FAILING_PUSH=""
}

olgene_load_env
TAG="$(olgene_stack_image_list | head -1)"
TAG="${TAG##*:}"

list="$(olgene_stack_image_list)"
check "image list has the init image" grep -q '^docker.io/library/busybox:' <<< "$list"
check "image list has seven images" test "$(wc -l <<< "$list" | tr -d ' ')" = 7

reset
cmd_images_push registry.example.com/gene/ >/dev/null 2>&1
status=$?
check "push succeeds" test "$status" = 0
for short in "apigene-backend:${TAG}" "apigene-copilot:${TAG}" "apigene-mcp-gw:${TAG}" \
  "apigene-nginx:${TAG}" mongo:7 redis:7-alpine busybox:1.36; do
  check "pushes ${short}" called "push registry.example.com/gene/${short}"
done
check "tags from the source image" called \
  "tag docker.io/library/mongo:7 registry.example.com/gene/mongo:7"

reset
cmd_images_push >/dev/null 2>&1
check "push without a registry fails" test "$?" != 0

reset
MISSING_IMAGE="docker.io/library/mongo:7"
cmd_images_push registry.example.com/gene >/dev/null 2>&1
check "missing image fails" test "$?" != 0
check "missing image pushes nothing" not_called "push"

reset
FAILING_PUSH="registry.example.com/gene/mongo:7"
cmd_images_push registry.example.com/gene >/dev/null 2>&1
check "failed push fails" test "$?" != 0
check "failed push stops" not_called "push registry.example.com/gene/redis"

echo "Passed: ${PASS}, Failed: ${FAIL}"
[[ "$FAIL" -eq 0 ]]
