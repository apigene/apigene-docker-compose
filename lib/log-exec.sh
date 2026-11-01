#!/bin/sh
# Duplicate a process's stdout/stderr into /var/log/apigene/<service>.jsonl,
# then exec the real command so it stays PID 1.
#
# Usage: log-exec.sh <service> <command> [args...]
set -u

svc="$1"
shift

if [ "$#" -eq 0 ]; then
  echo "log-exec: missing command" >&2
  exit 1
fi

dir=/var/log/apigene
file="${dir}/${svc}.jsonl"
pipe="/tmp/apigene-log-${svc}"

if ! command -v sed >/dev/null 2>&1 || ! command -v date >/dev/null 2>&1; then
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

/bin/sh /opt/apigene/log-writer.sh "$svc" "$file" < "$pipe" &

exec "$@" > "$pipe" 2>&1
