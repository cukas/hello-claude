#!/usr/bin/env bash
# hello-claude — list active sessions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

hc_cleanup_stale

CALLSIGN="$(hc_callsign)"
PREFIX="$(hc_label_prefix)"
SESSIONS_LABEL="$(hc_label_sessions)"

output="$(node -e "
  const fs = require('fs'), path = require('path'), os = require('os');
  const sessDir = process.argv[1], myCallsign = process.argv[2];
  const home = os.homedir(), now = Date.now();
  const lines = [];
  for (const f of fs.readdirSync(sessDir).filter(f => f.endsWith('.json'))) {
    try {
      const d = JSON.parse(fs.readFileSync(path.join(sessDir, f), 'utf8'));
      const me = d.callsign === myCallsign ? ' (you)' : '';
      const scope = d.scope ? ' — ' + d.scope : '';
      const cwd = d.cwd.replace(home, '~');
      const age = (now - new Date(d.last_seen).getTime()) / 1000;
      const ago = isNaN(age) ? 'unknown' : age < 60 ? 'just now' : age < 3600 ? Math.floor(age/60) + 'm ago' : Math.floor(age/3600) + 'h ago';
      lines.push('  ' + d.callsign + me + ' | ' + cwd + scope + ' | last seen ' + ago);
    } catch {}
  }
  if (!lines.length) { console.log('__EMPTY__'); }
  else { console.log(lines.join('\n')); }
" "$HC_SESSIONS" "$CALLSIGN" 2>/dev/null)"

if [[ "$output" == "__EMPTY__" ]]; then
  echo "[${PREFIX}] No active sessions."
else
  count="$(echo "$output" | wc -l | tr -d ' ')"
  echo "[${PREFIX}] ${SESSIONS_LABEL} (${count}):"
  echo "$output"
fi
