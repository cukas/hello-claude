#!/usr/bin/env bash
# hello-claude — shared library
set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
HC_DATA="${HOME}/.claude/hello-claude"
HC_SESSIONS="${HC_DATA}/sessions"
HC_INBOX="${HC_DATA}/inbox"
HC_THEME="${HELLO_CLAUDE_THEME:-default}"

# Ensure data dirs exist
mkdir -p "$HC_SESSIONS" "$HC_INBOX"

# ── Theme ────────────────────────────────────────────────────────────────────
hc_label_prefix() {
  case "$HC_THEME" in
    startrek) echo "BRIDGE" ;;
    *)        echo "hello-claude" ;;
  esac
}

hc_label_sessions() {
  case "$HC_THEME" in
    startrek) echo "Starfleet crew" ;;
    *)        echo "Active sessions" ;;
  esac
}

hc_label_message() {
  case "$HC_THEME" in
    startrek) echo "Incoming hail" ;;
    *)        echo "Message" ;;
  esac
}

hc_label_send() {
  case "$HC_THEME" in
    startrek) echo "Hailing" ;;
    *)        echo "Sending to" ;;
  esac
}

# ── Session identity ─────────────────────────────────────────────────────────
# Each session is identified by Claude Code's session ID (from env) or PID
hc_session_id() {
  # CLAUDE_SESSION_ID is set by Claude Code in hook env
  if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
    echo "$CLAUDE_SESSION_ID"
  else
    echo "pid-$$"
  fi
}

# Get or generate a callsign for this session
hc_callsign() {
  local sid
  sid="$(hc_session_id)"
  local name_file="${HC_DATA}/.callsign-${sid}"

  if [[ -f "$name_file" ]]; then
    cat "$name_file"
  else
    # Auto-name from working directory basename
    local auto_name
    auto_name="$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr ' .' '-')"
    echo "$auto_name" > "$name_file"
    echo "$auto_name"
  fi
}

# Set callsign explicitly
hc_set_callsign() {
  local sid
  sid="$(hc_session_id)"
  local name_file="${HC_DATA}/.callsign-${sid}"
  echo "$1" > "$name_file"
}

# ── PID utilities ────────────────────────────────────────────────────────────
hc_is_pid_alive() {
  local pid="$1"
  ps -p "$pid" > /dev/null 2>&1
}

# Clean stale sessions (PID dead + older than 5 min)
hc_cleanup_stale() {
  for f in "$HC_SESSIONS"/*.json; do
    [[ -f "$f" ]] || continue
    local pid
    pid="$(python3 -c "import json; print(json.load(open('$f'))['pid'])" 2>/dev/null || echo "")"
    if [[ -n "$pid" ]] && ! hc_is_pid_alive "$pid"; then
      rm -f "$f"
    fi
  done
}
