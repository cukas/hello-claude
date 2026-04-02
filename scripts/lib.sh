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
      sid="$(echo "$HC_HOOK_INPUT" | node -e "
        let d=''; process.stdin.on('data',c=>d+=c);
        process.stdin.on('end',()=>{try{console.log(JSON.parse(d).session_id||'')}catch{console.log('')}});
      " 2>/dev/null || echo "")"
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
  node - "$HC_SESSIONS" "$HC_DATA" <<'JSEOF'
const fs = require("fs"), path = require("path");
const [sessDir, dataDir] = process.argv.slice(2);
const now = Date.now(), stale = 1800_000;
const active = new Set();

// Clean stale sessions
for (const f of fs.readdirSync(sessDir).filter(f => f.endsWith(".json"))) {
  const fp = path.join(sessDir, f);
  try {
    const d = JSON.parse(fs.readFileSync(fp, "utf8"));
    const age = now - new Date(d.last_seen).getTime();
    if (isNaN(age) || age > stale) {
      const sid = d.session_id || "";
      if (sid) {
        try { fs.unlinkSync(path.join(dataDir, `.callsign-${sid}`)); } catch {}
        for (const p of fs.readdirSync(dataDir).filter(f => f.startsWith(".session-ppid-"))) {
          try {
            if (fs.readFileSync(path.join(dataDir, p), "utf8").trim() === sid)
              fs.unlinkSync(path.join(dataDir, p));
          } catch {}
        }
      }
      fs.unlinkSync(fp);
    } else {
      active.add(d.callsign || "");
    }
  } catch {}
}

// Clean orphaned callsign files
for (const f of fs.readdirSync(dataDir).filter(f => f.startsWith(".callsign-"))) {
  try {
    const callsign = fs.readFileSync(path.join(dataDir, f), "utf8").trim();
    if (!active.has(callsign)) fs.unlinkSync(path.join(dataDir, f));
  } catch {}
}
JSEOF
}
