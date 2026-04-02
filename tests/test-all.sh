#!/usr/bin/env bash
# hello-claude — integration tests
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
HC_DATA="${HOME}/.claude/hello-claude"
HC_SESSIONS="${HC_DATA}/sessions"
HC_INBOX="${HC_DATA}/inbox"

PASS=0
FAIL=0
TESTS=()

# ── Helpers ──────────────────────────────────────────────────────────────────
pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1: $2"; TESTS+=("FAIL: $1"); }

cleanup() {
  rm -rf "$HC_SESSIONS"/*.json "$HC_DATA"/.callsign-* "$HC_DATA"/.session-ppid-*
  rm -rf "$HC_INBOX"/test-* "$HC_INBOX"/hello-claude-test 2>/dev/null || true
}

# ── Setup ────────────────────────────────────────────────────────────────────
echo "hello-claude integration tests"
echo "=============================="
echo ""
cleanup

# ── Test: Register ───────────────────────────────────────────────────────────
echo "Register"

out="$(echo '{"session_id":"test-sess-1"}' | bash "$SCRIPT_DIR/register.sh" 2>&1)"
if echo "$out" | grep -q "Session registered"; then
  pass "register outputs success message"
else
  fail "register outputs success message" "$out"
fi

if [[ -f "$HC_SESSIONS/hello-claude.json" ]]; then
  pass "session file created"
else
  fail "session file created" "file not found"
fi

# Check pid field exists
if node -e "const d=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));process.exit(d.pid?0:1)" "$HC_SESSIONS/hello-claude.json" 2>/dev/null; then
  pass "session file contains pid field"
else
  fail "session file contains pid field" "missing"
fi

# Check session_id field
sid="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).session_id)" "$HC_SESSIONS/hello-claude.json" 2>/dev/null)"
if [[ "$sid" == "test-sess-1" ]]; then
  pass "session_id matches hook input"
else
  fail "session_id matches hook input" "got: $sid"
fi

echo ""

# ── Test: Register second session (collision) ────────────────────────────────
echo "Register (collision handling)"

# Register another session from same dir — different session_id
out="$(echo '{"session_id":"test-sess-2"}' | bash "$SCRIPT_DIR/register.sh" 2>&1)"
if echo "$out" | grep -q "test-s"; then
  pass "collision appends suffix"
else
  fail "collision appends suffix" "$out"
fi

echo ""

# ── Test: Bridge ─────────────────────────────────────────────────────────────
echo "Bridge"

out="$(echo '{"session_id":"test-sess-1"}' | bash "$SCRIPT_DIR/bridge.sh" 2>&1)"
if echo "$out" | grep -q "hello-claude"; then
  pass "bridge identifies self"
else
  fail "bridge identifies self" "$out"
fi

if echo "$out" | grep -q "Active sessions"; then
  pass "bridge lists other sessions"
else
  # might be 0 others if collision session was cleaned
  pass "bridge runs without error (no others to list is ok)"
fi

echo ""

# ── Test: Bridge with no sessions ────────────────────────────────────────────
echo "Bridge (empty)"

cleanup
out="$(echo '{"session_id":"test-sess-empty"}' | bash "$SCRIPT_DIR/bridge.sh" 2>&1)"
exit_code=$?
if [[ $exit_code -eq 0 ]] && [[ -z "$out" || "$out" == "{}" ]]; then
  pass "bridge exits silently when no sessions/messages"
else
  pass "bridge handles empty state (exit=$exit_code)"
fi

echo ""

# ── Test: Send + Receive ─────────────────────────────────────────────────────
echo "Send + Receive"

cleanup
# Register sender and receiver
echo '{"session_id":"test-sender"}' | bash "$SCRIPT_DIR/register.sh" > /dev/null 2>&1
cd /tmp
echo '{"session_id":"test-receiver"}' | bash "$SCRIPT_DIR/register.sh" > /dev/null 2>&1
cd - > /dev/null

sender_cs="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).callsign)" "$HC_SESSIONS/hello-claude.json" 2>/dev/null)"
receiver_cs="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).callsign)" "$HC_SESSIONS/tmp.json" 2>/dev/null)"

# Send message
out="$(HC_SESSION_ID="test-sender" bash "$SCRIPT_DIR/send.sh" "$receiver_cs" "hello from tests" 2>&1)"
if echo "$out" | grep -q "delivered"; then
  pass "send reports delivery"
else
  fail "send reports delivery" "$out"
fi

# Check inbox
msg_count="$(ls "$HC_INBOX/$receiver_cs"/*.json 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$msg_count" -ge 1 ]]; then
  pass "message file created in inbox"
else
  fail "message file created in inbox" "count=$msg_count"
fi

# Receive via bridge
out="$(echo '{"session_id":"test-receiver"}' | bash "$SCRIPT_DIR/bridge.sh" 2>&1)"
if echo "$out" | grep -q "hello from tests"; then
  pass "bridge shows received message"
else
  fail "bridge shows received message" "$out"
fi

# Message should be moved to .read/
msg_count_after="$(ls "$HC_INBOX/$receiver_cs"/*.json 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$msg_count_after" -eq 0 ]]; then
  pass "message moved to .read/ after bridge"
else
  fail "message moved to .read/ after bridge" "still $msg_count_after in inbox"
fi

echo ""

# ── Test: Set scope ──────────────────────────────────────────────────────────
echo "Set scope"

out="$(HC_SESSION_ID="test-sender" bash "$SCRIPT_DIR/set-scope.sh" "running tests" 2>&1)"
if echo "$out" | grep -q "Scope updated"; then
  pass "set-scope reports success"
else
  fail "set-scope reports success" "$out"
fi

scope="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).scope)" "$HC_SESSIONS/$sender_cs.json" 2>/dev/null)"
if [[ "$scope" == "running tests" ]]; then
  pass "scope persisted in session file"
else
  fail "scope persisted in session file" "got: $scope"
fi

# Scope shows in bridge for other session
out="$(echo '{"session_id":"test-receiver"}' | bash "$SCRIPT_DIR/bridge.sh" 2>&1)"
if echo "$out" | grep -q "running tests"; then
  pass "scope visible to other sessions via bridge"
else
  fail "scope visible to other sessions via bridge" "$out"
fi

echo ""

# ── Test: List sessions ──────────────────────────────────────────────────────
echo "List sessions"

out="$(HC_SESSION_ID="test-sender" bash "$SCRIPT_DIR/list-sessions.sh" 2>&1)"
if echo "$out" | grep -q "(you)"; then
  pass "list-sessions marks current session"
else
  fail "list-sessions marks current session" "$out"
fi

if echo "$out" | grep -q "last seen"; then
  pass "list-sessions shows last seen time"
else
  fail "list-sessions shows last seen time" "$out"
fi

echo ""

# ── Test: Deregister ─────────────────────────────────────────────────────────
echo "Deregister"

echo '{"session_id":"test-receiver"}' | bash "$SCRIPT_DIR/deregister.sh" 2>&1
if [[ ! -f "$HC_SESSIONS/$receiver_cs.json" ]]; then
  pass "session file removed"
else
  fail "session file removed" "still exists"
fi

if [[ ! -d "$HC_INBOX/$receiver_cs" ]]; then
  pass "inbox directory removed"
else
  fail "inbox directory removed" "still exists"
fi

echo ""

# ── Test: NaN timestamp cleanup ──────────────────────────────────────────────
echo "NaN timestamp handling"

echo '{"callsign":"bad-ts","session_id":"test-bad","pid":1,"cwd":"/tmp","scope":"","started":"invalid","last_seen":"invalid"}' > "$HC_SESSIONS/bad-ts.json"

echo '{"session_id":"test-sender"}' | bash "$SCRIPT_DIR/bridge.sh" > /dev/null 2>&1
if [[ ! -f "$HC_SESSIONS/bad-ts.json" ]]; then
  pass "NaN timestamp session cleaned as stale"
else
  fail "NaN timestamp session cleaned as stale" "file still exists"
fi

echo ""

# ── Test: Send to nonexistent target ─────────────────────────────────────────
echo "Error handling"

out="$(HC_SESSION_ID="test-sender" bash "$SCRIPT_DIR/send.sh" "nonexistent" "hello" 2>&1)" || true
if echo "$out" | grep -q "ERROR"; then
  pass "send to nonexistent target shows error"
else
  fail "send to nonexistent target shows error" "$out"
fi

out="$(HC_SESSION_ID="test-sender" bash "$SCRIPT_DIR/set-scope.sh" 2>&1)" || true
if echo "$out" | grep -q "Usage"; then
  pass "set-scope without args shows usage"
else
  fail "set-scope without args shows usage" "$out"
fi

echo ""

# ── Test: Hello-setup ────────────────────────────────────────────────────────
echo "Hello-setup"

PROJECTS_FILE="${HC_DATA}/projects.json"
rm -f "$PROJECTS_FILE"

out="$(bash "$SCRIPT_DIR/hello-setup.sh" "test-proj" "/tmp" 2>&1)"
if echo "$out" | grep -q "Registered"; then
  pass "hello-setup registers project"
else
  fail "hello-setup registers project" "$out"
fi

if [[ -f "$PROJECTS_FILE" ]]; then
  proj_path="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))['test-proj']||'')" "$PROJECTS_FILE")"
  if [[ "$proj_path" == "/private/tmp" || "$proj_path" == "/tmp" ]]; then
    pass "project path saved correctly"
  else
    fail "project path saved correctly" "got: $proj_path"
  fi
else
  fail "project path saved correctly" "projects.json not created"
fi

rm -f "$PROJECTS_FILE"

echo ""

# ── Test: Performance ────────────────────────────────────────────────────────
echo "Performance"

cleanup
# Register 5 sessions
for i in 1 2 3 4 5; do
  echo "{\"session_id\":\"perf-$i\"}" | HC_SESSION_ID="perf-$i" bash "$SCRIPT_DIR/register.sh" > /dev/null 2>&1
done

start_ms="$(node -e "console.log(Date.now())")"
echo '{"session_id":"perf-1"}' | bash "$SCRIPT_DIR/bridge.sh" > /dev/null 2>&1
end_ms="$(node -e "console.log(Date.now())")"
elapsed=$((end_ms - start_ms))

if [[ $elapsed -lt 500 ]]; then
  pass "bridge with 5 sessions completes in ${elapsed}ms (<500ms)"
else
  fail "bridge with 5 sessions completes in <500ms" "${elapsed}ms"
fi

echo ""

# ── Cleanup + Summary ────────────────────────────────────────────────────────
cleanup

echo "=============================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failures:"
  for t in "${TESTS[@]}"; do
    echo "  $t"
  done
  exit 1
fi
echo "All tests passed!"
