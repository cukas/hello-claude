#!/usr/bin/env bash
# hello-claude — list active sessions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

hc_cleanup_stale

CALLSIGN="$(hc_callsign)"
PREFIX="$(hc_label_prefix)"
SESSIONS_LABEL="$(hc_label_sessions)"

count=0
output=""
for f in "$HC_SESSIONS"/*.json; do
  [[ -f "$f" ]] || continue
  info="$(python3 -c "
import json, datetime, os
with open('$f') as fh:
    d = json.load(fh)
me = ' (you)' if d['callsign'] == '${CALLSIGN}' else ''
scope = f' — {d[\"scope\"]}' if d.get('scope') else ''
cwd_short = d['cwd'].replace(os.path.expanduser('~'), '~')
last = datetime.datetime.fromisoformat(d['last_seen'])
age = (datetime.datetime.now() - last).total_seconds()
if age < 60:
    ago = 'just now'
elif age < 3600:
    ago = f'{int(age/60)}m ago'
else:
    ago = f'{int(age/3600)}h ago'
print(f'  {d[\"callsign\"]}{me} | {cwd_short}{scope} | last seen {ago}')
" 2>/dev/null || true)"
  if [[ -n "$info" ]]; then
    output="${output}${info}\n"
    count=$((count + 1))
  fi
done

if [[ $count -eq 0 ]]; then
  echo "[${PREFIX}] No active sessions."
else
  echo -e "[${PREFIX}] ${SESSIONS_LABEL} (${count}):\n${output}"
fi
