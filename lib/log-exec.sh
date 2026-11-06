#!/bin/sh
# Copy a process's stdout/stderr into /var/log/olgene/<service>.jsonl and
# leave the container's original stdout in place, then exec the real command
# so it stays PID 1.
#
# `docker logs` / `podman logs` read that original stdout. Replacing it (the
# previous behavior) hid lines such as "celery@… ready" from anything that
# tails the container log.
#
# Usage: log-exec.sh <service> <command> [args...]
set -u

svc="$1"
shift

if [ "$#" -eq 0 ]; then
  echo "log-exec: missing command" >&2
  exit 1
fi

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
writer="${here}/log-writer.sh"
dir="${LOG_DIR:-/var/log/olgene}"
file="${dir}/${svc}.jsonl"
pipe="/tmp/apigene-log-${svc}"

if ! command -v sed >/dev/null 2>&1 || ! command -v date >/dev/null 2>&1 || [ ! -f "$writer" ]; then
  exec "$@"
fi

mkdir -p "$dir" 2>/dev/null || true
chmod 1777 "$dir" 2>/dev/null || true
if ! touch "$file" 2>/dev/null; then
  exec "$@"
fi
chmod 644 "$file" 2>/dev/null || true

rm -f "$pipe"
if ! mkfifo "$pipe" 2>/dev/null; then
  exec "$@"
fi

# fd 3 is the stdout the log driver already attached. The writer reprints each
# raw line there. The app only writes the fifo, and stays PID 1.
exec 3>&1
/bin/sh "$writer" "$svc" "$file" < "$pipe" >&3 3>&- &
exec "$@" > "$pipe" 2>&1 3>&-
