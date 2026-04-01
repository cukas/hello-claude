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

# ── Hook input ───────────────────────────────────────────────────────────────
# Claude Code passes JSON on stdin to hooks. Call this once per hook script.
hc_read_hook_input() {
  if [[ ! -t 0 ]]; then
    HC_HOOK_INPUT="$(cat)"
    export HC_HOOK_INPUT
    if [[ -n "$HC_HOOK_INPUT" ]]; then
      local sid
      sid="$(echo "$HC_HOOK_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null || echo "")"
      if [[ -n "$sid" ]]; then
        export HC_SESSION_ID="$sid"
        # Persist mapping so non-hook scripts (skills) can find it via PPID
        echo "$sid" > "${HC_DATA}/.session-ppid-${PPID}"
      fi
    fi
  fi
}

# ── Session identity ─────────────────────────────────────────────────────────
hc_session_id() {
  # 1. Already set (from hc_read_hook_input)
  if [[ -n "${HC_SESSION_ID:-}" ]]; then
    echo "$HC_SESSION_ID"
    return
  fi
  # 2. Claude Code env var
  if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
    echo "$CLAUDE_SESSION_ID"
    return
  fi
  # 3. Look up persisted mapping by PPID (written by register.sh)
  local mapping="${HC_DATA}/.session-ppid-${PPID}"
  if [[ -f "$mapping" ]]; then
    cat "$mapping"
    return
  fi
  # 4. Fallback to PPID-based ID
  echo "pid-${PPID}"
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

# ── Cleanup ──────────────────────────────────────────────────────────────────
# Clean stale sessions (last_seen older than 30 min)
hc_cleanup_stale() {
  local stale_seconds=1800
  local now
  now="$(date +%s)"
  for f in "$HC_SESSIONS"/*.json; do
    [[ -f "$f" ]] || continue
    local last_seen_ts
    last_seen_ts="$(python3 -c "
import json, datetime
with open('$f') as fh:
    d = json.load(fh)
ls = datetime.datetime.fromisoformat(d['last_seen'])
print(int(ls.timestamp()))
" 2>/dev/null || echo "0")"
    if (( now - last_seen_ts > stale_seconds )); then
      # Clean up associated callsign + mapping files
      local sid
      sid="$(python3 -c "import json; print(json.load(open('$f')).get('session_id',''))" 2>/dev/null || echo "")"
      [[ -n "$sid" ]] && rm -f "${HC_DATA}/.callsign-${sid}"
      rm -f "$f"
    fi
  done

  # Clean orphaned callsign files (no matching session)
  for cf in "$HC_DATA"/.callsign-*; do
    [[ -f "$cf" ]] || continue
    local callsign
    callsign="$(cat "$cf")"
    if [[ ! -f "${HC_SESSIONS}/${callsign}.json" ]]; then
      rm -f "$cf"
    fi
  done
}
