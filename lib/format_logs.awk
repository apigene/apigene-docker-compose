# Colorize docker compose log lines (service prefix + level + HTTP status).
# Streaming-safe: processes one line at a time.

BEGIN {
  use_color = (ENVIRON["NO_COLOR"] == "")
  reset = use_color ? "\033[0m" : ""
  bold  = use_color ? "\033[1m" : ""
  dim   = use_color ? "\033[2m" : ""
  c_red     = use_color ? "\033[0;31m" : ""
  c_green   = use_color ? "\033[0;32m" : ""
  c_yellow  = use_color ? "\033[0;33m" : ""
  c_blue    = use_color ? "\033[0;34m" : ""
  c_magenta = use_color ? "\033[0;35m" : ""
  c_cyan    = use_color ? "\033[0;36m" : ""
  c_gray    = use_color ? "\033[0;90m" : ""
}

function service_color(name,    n) {
  n = tolower(name)
  if (n ~ /^backend-worker/) return c_green dim
  if (n ~ /^backend/) return c_green
  if (n ~ /^nginx/) return c_cyan
  if (n ~ /^copilot/) return c_magenta
  if (n ~ /^mcp-gw/) return c_blue
  if (n ~ /^mongo/) return c_yellow
  if (n ~ /^redis/) return c_red
  return c_gray
}

function status_color(code,    c) {
  c = code + 0
  if (c >= 500) return c_red bold
  if (c >= 400) return c_yellow
  if (c >= 300) return c_cyan
  if (c >= 200) return c_green
  return ""
}

function colorize_levels(msg) {
  gsub(/ERROR:/, c_red bold "ERROR" reset ":", msg)
  gsub(/CRITICAL:/, c_red bold "CRITICAL" reset ":", msg)
  gsub(/FATAL:/, c_red bold "FATAL" reset ":", msg)
  gsub(/WARNING:/, c_yellow "WARNING" reset ":", msg)
  gsub(/WARN:/, c_yellow "WARN" reset ":", msg)
  gsub(/INFO:/, c_gray "INFO" reset ":", msg)
  gsub(/DEBUG:/, c_gray dim "DEBUG" reset ":", msg)
  return msg
}

function colorize_status(msg,    code, col, pos, abs, tail) {
  pos = 1
  while (match(substr(msg, pos), /HTTP\/[0-9.]+" ([0-9]{3})/)) {
    abs = pos + RSTART - 1
    code = substr(msg, abs + RLENGTH - 3, 3)
    col = status_color(code)
    tail = substr(msg, abs + RLENGTH)
    msg = substr(msg, 1, abs + RLENGTH - 4) col code reset tail
    pos = abs + RLENGTH - 3 + length(col) + length(code) + length(reset) + 1
  }
  pos = 1
  while (match(substr(msg, pos), / ([0-9]{3}) completed /)) {
    abs = pos + RSTART - 1
    code = substr(msg, abs + 1, 3)
    col = status_color(code)
    tail = substr(msg, abs + 4)
    msg = substr(msg, 1, abs) col code reset tail
    pos = abs + length(col) + length(code) + length(reset) + 4
  }
  return msg
}

{
  if (match($0, /^([a-zA-Z0-9._-]+) *\| (.*)$/)) {
    service = substr($0, 1, index($0, "|") - 1)
    gsub(/[[:space:]]+$/, "", service)
    message = substr($0, index($0, "|") + 1)
    sub(/^[[:space:]]+/, "", message)
    message = colorize_levels(message)
    message = colorize_status(message)
    printf "%s%-18s%s %s %s\n", service_color(service), service, reset, dim "|" reset, message
    next
  }
  print $0
}
