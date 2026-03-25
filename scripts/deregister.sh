#!/usr/bin/env bash
# hello-claude — deregister session on end
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

CALLSIGN="$(hc_callsign)"
SESSION_FILE="${HC_SESSIONS}/${CALLSIGN}.json"

# Remove session file
rm -f "$SESSION_FILE"

# Clean callsign mapping
SID="$(hc_session_id)"
rm -f "${HC_DATA}/.callsign-${SID}"
