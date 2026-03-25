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

python3 -c "
import json
with open('${SESSION_FILE}', 'r') as f:
    data = json.load(f)
data['scope'] = '''${SCOPE}'''
with open('${SESSION_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
"

echo "Scope updated: ${SCOPE}"
