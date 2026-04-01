#!/usr/bin/env bash
# hello-claude — bridge scanner (UserPromptSubmit hook)
# Reads active sessions + inbox, injects awareness into context
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

# Read hook input from stdin (captures session_id)
hc_read_hook_input

# Clean stale sessions
hc_cleanup_stale

CALLSIGN="$(hc_callsign)"
PREFIX="$(hc_label_prefix)"
SESSIONS_LABEL="$(hc_label_sessions)"
MSG_LABEL="$(hc_label_message)"

# Update last_seen timestamp
SESSION_FILE="${HC_SESSIONS}/${CALLSIGN}.json"
if [[ -f "$SESSION_FILE" ]]; then
  python3 << PYEOF
import json, datetime
with open("${SESSION_FILE}", "r") as f:
    data = json.load(f)
data["last_seen"] = datetime.datetime.now().isoformat()
with open("${SESSION_FILE}", "w") as f:
    json.dump(data, f, indent=2)
PYEOF
fi

# ── Collect active sessions ──────────────────────────────────────────────────
others=""
count=0
for f in "$HC_SESSIONS"/*.json; do
  [[ -f "$f" ]] || continue
  info="$(python3 -c "
import json, os
with open('$f') as fh:
    d = json.load(fh)
if d['callsign'] != '${CALLSIGN}':
    scope = f' — {d[\"scope\"]}' if d.get('scope') else ''
    cwd_short = d['cwd'].replace(os.path.expanduser('~'), '~')
    print(f'  - {d[\"callsign\"]} ({cwd_short}){scope}')
" 2>/dev/null || true)"
  if [[ -n "$info" ]]; then
    others="${others}${info}\n"
    count=$((count + 1))
  fi
done

# ── Collect inbox messages ───────────────────────────────────────────────────
inbox_dir="${HC_INBOX}/${CALLSIGN}"
messages=""
msg_count=0
if [[ -d "$inbox_dir" ]]; then
  for msg_file in "$inbox_dir"/*.json; do
    [[ -f "$msg_file" ]] || continue
    msg_info="$(python3 -c "
import json
with open('$msg_file') as fh:
    m = json.load(fh)
print(f'  From {m[\"from\"]}: {m[\"body\"]}')
" 2>/dev/null || true)"
    if [[ -n "$msg_info" ]]; then
      messages="${messages}${msg_info}\n"
      msg_count=$((msg_count + 1))
    fi
    # Mark as read by moving to .read/
    mkdir -p "${inbox_dir}/.read"
    mv "$msg_file" "${inbox_dir}/.read/" 2>/dev/null || true
  done
fi

# ── Build output ─────────────────────────────────────────────────────────────
# Only emit if there's something to report
if [[ $count -eq 0 ]] && [[ $msg_count -eq 0 ]]; then
  exit 0
fi

output="[${PREFIX}] You are '${CALLSIGN}'."

if [[ $count -gt 0 ]]; then
  output="${output}\n${SESSIONS_LABEL} (${count}):\n${others}"
fi

if [[ $msg_count -gt 0 ]]; then
  output="${output}\n${MSG_LABEL}s (${msg_count}):\n${messages}"
  output="${output}\nReply with: /msg <callsign> \"your reply\""
fi

# Escape for JSON
json_output="$(echo -e "$output" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")"

echo "{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":${json_output}}}"
