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
    node -e "
      const fs = require('fs');
      try {
        const p = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
        for (const [name, path] of Object.entries(p)) console.log('  ' + name + ' -> ' + path);
      } catch {}
    " "${HC_DATA}/projects.json" 2>/dev/null
  else
    echo "  (none configured — run /hello-setup to add projects)" >&2
  fi
  exit 1
fi

# Resolve project path
PROJECT_PATH=""

# 1. Check projects.json config
if [[ -f "${HC_DATA}/projects.json" ]]; then
  PROJECT_PATH="$(node -e "
    const fs = require('fs');
    try {
      const p = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
      console.log(p[process.argv[2]] || '');
    } catch { console.log(''); }
  " "${HC_DATA}/projects.json" "$TARGET" 2>/dev/null || true)"
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

# Check if there's a live session for this project — single node call
live_callsign="$(node -e "
  const fs = require('fs'), path = require('path');
  const sessDir = process.argv[1], projPath = process.argv[2];
  for (const f of fs.readdirSync(sessDir).filter(f => f.endsWith('.json'))) {
    try {
      const d = JSON.parse(fs.readFileSync(path.join(sessDir, f), 'utf8'));
      if (d.cwd === projPath && d.pid) {
        // Check if process is still alive
        try { process.kill(d.pid, 0); console.log(d.callsign); process.exit(0); }
        catch {}
      }
    } catch {}
  }
  console.log('');
" "$HC_SESSIONS" "$PROJECT_PATH" 2>/dev/null || true)"

if [[ -n "$live_callsign" ]]; then
  bash "${SCRIPT_DIR}/send.sh" "$live_callsign" "$MESSAGE" 2>/dev/null || true
  echo "[hello-claude] Message also sent to live session '${live_callsign}' — they'll see it on next prompt."
  echo ""
fi

# Spawn a Claude to answer immediately
echo "[hello-claude] Asking ${TARGET}..."
echo ""

claude -p \
  --cwd "$PROJECT_PATH" \
  "You are being contacted by another Claude Code session working on a different project. Answer their question concisely. Their message: ${MESSAGE}" \
  2>/dev/null
