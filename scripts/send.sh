#!/usr/bin/env bash
# hello-claude — send a message to another session
# Usage: send.sh <target-callsign> <message> [--reply-to <msg-id>]
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

TARGET="${1:-}"
BODY="${2:-}"
REPLY_TO=""

shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reply-to) REPLY_TO="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$TARGET" ]] || [[ -z "$BODY" ]]; then
  echo "Usage: send.sh <callsign> \"message\"" >&2
  exit 1
fi

# Check target exists
if [[ ! -f "${HC_SESSIONS}/${TARGET}.json" ]]; then
  echo "ERROR: No active session named '${TARGET}'." >&2
  echo "Active sessions:" >&2
  for f in "$HC_SESSIONS"/*.json; do
    [[ -f "$f" ]] || continue
    basename "$f" .json >&2
  done
  exit 1
fi

FROM="$(hc_callsign)"
SEND_LABEL="$(hc_label_send)"

# Create message
TARGET_INBOX="${HC_INBOX}/${TARGET}"
mkdir -p "$TARGET_INBOX"

MSG_ID="$(date +%s)-${RANDOM}"
MSG_FILE="${TARGET_INBOX}/${MSG_ID}.json"

node -e "
  const fs = require('fs');
  const msg = {
    id: process.argv[1],
    from: process.argv[2],
    to: process.argv[3],
    body: process.argv[4],
    reply_to: process.argv[5] || null,
    timestamp: new Date().toISOString()
  };
  fs.writeFileSync(process.argv[6], JSON.stringify(msg, null, 2));
" "$MSG_ID" "$FROM" "$TARGET" "$BODY" "$REPLY_TO" "$MSG_FILE"

echo "${SEND_LABEL} ${TARGET}: message delivered. They'll see it on their next prompt."
