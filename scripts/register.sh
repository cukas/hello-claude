#!/usr/bin/env bash
# hello-claude — register session on start
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

# Read hook input from stdin (captures session_id)
hc_read_hook_input

# Clean up stale sessions first
hc_cleanup_stale

CALLSIGN="$(hc_callsign)"
SID="$(hc_session_id)"
SESSION_FILE="${HC_SESSIONS}/${CALLSIGN}.json"

# If callsign already taken by a different session, append a suffix
if [[ -f "$SESSION_FILE" ]]; then
  existing_sid="$(node -e "
    try{console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).session_id||'')}
    catch{console.log('')}
  " "$SESSION_FILE" 2>/dev/null || echo "")"
  if [[ "$existing_sid" != "$SID" ]]; then
    # Name collision with a different session — append short hash
    CALLSIGN="${CALLSIGN}-${SID:0:6}"
    hc_set_callsign "$CALLSIGN"
    SESSION_FILE="${HC_SESSIONS}/${CALLSIGN}.json"
  fi
fi

# Ensure inbox exists
mkdir -p "${HC_INBOX}/${CALLSIGN}"

# Write session file (PPID = Claude Code process for liveness checks)
node -e "
  const fs = require('fs');
  const data = {
    callsign: process.argv[1],
    session_id: process.argv[2],
    pid: parseInt(process.argv[3], 10),
    cwd: process.cwd(),
    scope: '',
    started: new Date().toISOString(),
    last_seen: new Date().toISOString()
  };
  fs.writeFileSync(process.argv[4], JSON.stringify(data, null, 2));
" "$CALLSIGN" "$SID" "$PPID" "$SESSION_FILE"

# Output for SessionStart hook
PREFIX="$(hc_label_prefix)"
cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[${PREFIX}] Session registered as '${CALLSIGN}'. Other Claude sessions can reach you at this callsign. Use /msg to send messages to other active sessions, or /sessions to see who's online."}}
EOF
