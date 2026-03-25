#!/usr/bin/env bash
# hello-claude — walkie-talkie to another project's Claude
# Usage: hello.sh <project> <message>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

TARGET="${1:-}"
shift 2>/dev/null || true
MESSAGE="$*"

if [[ -z "$TARGET" ]] || [[ -z "$MESSAGE" ]]; then
  echo "Usage: /hello <project> <message>" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  /hello kern-lang what's the current rule count?" >&2
  echo "  /hello kern-lang-landing update the docs with 76 rules" >&2
  echo "" >&2
  # List known projects
  echo "Known projects:" >&2
  if [[ -f "${HC_DATA}/projects.json" ]]; then
    python3 -c "
import json
with open('${HC_DATA}/projects.json') as f:
    projects = json.load(f)
for name, path in projects.items():
    print(f'  {name} -> {path}')
" 2>/dev/null
  else
    echo "  (none configured — run /hello-setup to add projects)" >&2
  fi
  exit 1
fi

# Resolve project path
PROJECT_PATH=""

# 1. Check projects.json config
if [[ -f "${HC_DATA}/projects.json" ]]; then
  PROJECT_PATH="$(python3 -c "
import json
with open('${HC_DATA}/projects.json') as f:
    projects = json.load(f)
print(projects.get('${TARGET}', ''))
" 2>/dev/null || true)"
fi

# 2. Fallback: try ~/GitHub/<target>
if [[ -z "$PROJECT_PATH" ]] && [[ -d "${HOME}/GitHub/${TARGET}" ]]; then
  PROJECT_PATH="${HOME}/GitHub/${TARGET}"
fi

if [[ -z "$PROJECT_PATH" ]] || [[ ! -d "$PROJECT_PATH" ]]; then
  echo "ERROR: Unknown project '${TARGET}'." >&2
  echo "Add it with: /hello-setup ${TARGET} /path/to/project" >&2
  exit 1
fi

# Check if there's a live session for this project — route to inbox
for f in "$HC_SESSIONS"/*.json; do
  [[ -f "$f" ]] || continue
  session_cwd="$(python3 -c "import json; print(json.load(open('$f'))['cwd'])" 2>/dev/null || true)"
  if [[ "$session_cwd" == "$PROJECT_PATH" ]]; then
    session_name="$(python3 -c "import json; print(json.load(open('$f'))['callsign'])" 2>/dev/null || true)"
    session_pid="$(python3 -c "import json; print(json.load(open('$f'))['pid'])" 2>/dev/null || true)"
    if ps -p "$session_pid" > /dev/null 2>&1; then
      # Live session — send to inbox AND spawn immediate response
      bash "${SCRIPT_DIR}/send.sh" "$session_name" "$MESSAGE" 2>/dev/null || true
      echo "[hello-claude] Message also sent to live session '${session_name}' — they'll see it on next prompt."
      echo ""
    fi
  fi
done

# Spawn a Claude to answer immediately
echo "[hello-claude] Asking ${TARGET}..."
echo ""

claude -p \
  --cwd "$PROJECT_PATH" \
  "You are being contacted by another Claude Code session working on a different project. Answer their question concisely. Their message: ${MESSAGE}" \
  2>/dev/null
