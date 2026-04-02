#!/usr/bin/env bash
# hello-claude — set the current session's scope/task description
# Usage: set-scope.sh "working on AST refactor"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

SCOPE="${1:-}"
if [[ -z "$SCOPE" ]]; then
  echo "Usage: set-scope.sh \"description of what you're working on\"" >&2
  exit 1
fi

CALLSIGN="$(hc_callsign)"
SESSION_FILE="${HC_SESSIONS}/${CALLSIGN}.json"

if [[ ! -f "$SESSION_FILE" ]]; then
  echo "ERROR: Session not registered. Start a new session first." >&2
  exit 1
fi

node -e "
  const fs = require('fs');
  const data = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
  data.scope = process.argv[2];
  fs.writeFileSync(process.argv[1], JSON.stringify(data, null, 2));
" "$SESSION_FILE" "$SCOPE"

echo "Scope updated: ${SCOPE}"
