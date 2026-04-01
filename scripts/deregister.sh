#!/usr/bin/env bash
# hello-claude — deregister session on end
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

# Read hook input from stdin (captures session_id)
hc_read_hook_input

SID="$(hc_session_id)"
CALLSIGN="$(hc_callsign)"
SESSION_FILE="${HC_SESSIONS}/${CALLSIGN}.json"

# Remove session file
rm -f "$SESSION_FILE"

# Clean callsign mapping, PPID mapping, and inbox
rm -f "${HC_DATA}/.callsign-${SID}"
rm -f "${HC_DATA}/.session-ppid-${PPID}"
rm -rf "${HC_INBOX}/${CALLSIGN}/.read" 2>/dev/null || true
