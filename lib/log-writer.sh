#!/bin/sh
# Read log lines on stdin, reprint each one on stdout, and append JSONL.
# Rotates at LOG_ROTATE_BYTES (default 20MB), keeping the active file plus
# four archives. log-exec.sh points stdout at the container's original stdout.
set -u

svc="$1"
file="$2"
max_bytes="${LOG_ROTATE_BYTES:-20971520}"
keep=4

rotate() {
  i=$keep
  while [ "$i" -gt 1 ]; do
    prev=$((i - 1))
    if [ -f "${file}.${prev}" ]; then
      mv "${file}.${prev}" "${file}.${i}"
    fi
    i=$prev
  done
  if [ -f "$file" ]; then
    mv "$file" "${file}.1"
  fi
}

n=0
while IFS= read -r line || [ -n "$line" ]; do
  n=$((n + 1))
  if [ $((n % 20)) -eq 0 ]; then
    bytes=$(wc -c < "$file" 2>/dev/null | tr -d '[:space:]')
    bytes=${bytes:-0}
    if [ "$bytes" -gt "$max_bytes" ]; then
      rotate
    fi
  fi
  # Container log first, so a slow JSON append cannot hide the line from
  # `docker logs` / `podman logs`.
  printf '%s\n' "$line"
  esc=$(printf '\033')
  clean=$(printf '%s' "$line" | sed "s/${esc}\\[[0-9;]*[A-Za-z]//g" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r')
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '%s\n' "{\"ts\":\"${ts}\",\"service\":\"${svc}\",\"line\":\"${clean}\"}" >> "$file"
done
