#!/usr/bin/env bash
# Unit tests for ./olgene package helpers. Nothing is pulled or packaged.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/lib/ui.sh"
# shellcheck disable=SC1091
source "$ROOT/lib/cmd_package.sh"

PASS=0
FAIL=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

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

printf 'DEPLOYMENT_TYPE=SaaS\n# LICENSE_PUBLIC_KEY=\n' > "$WORK/.env"
OL_LICENSE_PUBLIC_KEY="base64:QUJD+/9=" olgene_package_set_license_key "$WORK/.env" >/dev/null 2>&1
check "writes the license key" grep -qxF "LICENSE_PUBLIC_KEY=base64:QUJD+/9=" "$WORK/.env"

printf 'DEPLOYMENT_TYPE=SaaS\n' > "$WORK/.env"
OL_LICENSE_PUBLIC_KEY="" olgene_package_set_license_key "$WORK/.env" >/dev/null 2>&1
check "fails without a key" test "$?" != 0
check "writes nothing without a key" bash -c "! grep -q LICENSE_PUBLIC_KEY= '$WORK/.env'"

printf 'DEPLOYMENT_TYPE=SaaS\n' > "$WORK/.env"
OL_LICENSE_PUBLIC_KEY=$'-----BEGIN PUBLIC KEY-----\nabc' olgene_package_set_license_key "$WORK/.env" >/dev/null 2>&1
check "rejects a multi-line key" test "$?" != 0

echo "Passed: ${PASS}, Failed: ${FAIL}"
[[ "$FAIL" -eq 0 ]]
