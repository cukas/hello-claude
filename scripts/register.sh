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
  existing_sid="$(python3 -c "import json; print(json.load(open('$SESSION_FILE')).get('session_id',''))" 2>/dev/null || echo "")"
  if [[ "$existing_sid" != "$SID" ]]; then
    # Name collision with a different session — append short hash
    CALLSIGN="${CALLSIGN}-${SID:0:6}"
    hc_set_callsign "$CALLSIGN"
    SESSION_FILE="${HC_SESSIONS}/${CALLSIGN}.json"
  fi
fi

# Ensure inbox exists
mkdir -p "${HC_INBOX}/${CALLSIGN}"

# Write session file — pass values via stdin to avoid shell injection
python3 << PYEOF
import json, os, datetime
data = {
    "callsign": "${CALLSIGN}",
    "session_id": "${SID}",
    "cwd": os.getcwd(),
    "scope": "",
    "started": datetime.datetime.now().isoformat(),
    "last_seen": datetime.datetime.now().isoformat()
}
with open("${SESSION_FILE}", "w") as f:
    json.dump(data, f, indent=2)
PYEOF

# Output for SessionStart hook — tells Claude about the registration
PREFIX="$(hc_label_prefix)"
cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[${PREFIX}] Session registered as '${CALLSIGN}'. Other Claude sessions can reach you at this callsign. Use /msg to send messages to other active sessions, or /sessions to see who's online."}}
EOF
