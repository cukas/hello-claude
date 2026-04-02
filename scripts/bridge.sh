#!/usr/bin/env bash
# hello-claude — bridge scanner (UserPromptSubmit hook)
# Reads active sessions + inbox, injects awareness into context
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

# Read hook input from stdin (captures session_id + writes PPID mapping)
hc_read_hook_input

CALLSIGN="$(hc_callsign)"
SID="$(hc_session_id)"

# Single node call for: cleanup, last_seen update, session list, inbox
exec node - "$HC_SESSIONS" "$HC_INBOX" "$HC_DATA" "$CALLSIGN" "$SID" "$HC_THEME" <<'JSEOF'
const fs = require("fs"), path = require("path"), os = require("os");
const [sessDir, inboxDir, dataDir, myCallsign, mySid, theme] = process.argv.slice(2);
const now = Date.now(), stale = 1800_000, home = os.homedir();

// Theme labels
const [prefix, sessLabel, msgLabel] = theme === "startrek"
  ? ["BRIDGE", "Starfleet crew", "Incoming hail"]
  : ["hello-claude", "Active sessions", "Message"];

// ── Cleanup stale sessions (no orphan callsign cleanup on hot path) ─────────
for (const f of fs.readdirSync(sessDir).filter(f => f.endsWith(".json"))) {
  const fp = path.join(sessDir, f);
  try {
    const d = JSON.parse(fs.readFileSync(fp, "utf8"));
    const age = now - new Date(d.last_seen).getTime();
    if (isNaN(age) || age > stale) {
      const sid = d.session_id || "";
      if (sid) {
        try { fs.unlinkSync(path.join(dataDir, `.callsign-${sid}`)); } catch {}
        for (const p of fs.readdirSync(dataDir).filter(x => x.startsWith(".session-ppid-"))) {
          try {
            if (fs.readFileSync(path.join(dataDir, p), "utf8").trim() === sid)
              fs.unlinkSync(path.join(dataDir, p));
          } catch {}
        }
      }
      fs.unlinkSync(fp);
    }
  } catch {}
}

// ── Update last_seen (find by session_id, not callsign filename) ────────────
for (const f of fs.readdirSync(sessDir).filter(f => f.endsWith(".json"))) {
  const fp = path.join(sessDir, f);
  try {
    const d = JSON.parse(fs.readFileSync(fp, "utf8"));
    if (d.session_id === mySid) {
      d.last_seen = new Date().toISOString();
      fs.writeFileSync(fp, JSON.stringify(d, null, 2));
      break;
    }
  } catch {}
}

// ── Collect other active sessions ───────────────────────────────────────────
const others = [];
for (const f of fs.readdirSync(sessDir).filter(f => f.endsWith(".json"))) {
  try {
    const d = JSON.parse(fs.readFileSync(path.join(sessDir, f), "utf8"));
    if (d.callsign !== myCallsign) {
      const cwd = d.cwd.replace(home, "~");
      const scope = d.scope ? ` — ${d.scope}` : "";
      others.push(`  - ${d.callsign} (${cwd})${scope}`);
    }
  } catch {}
}

// ── Collect inbox messages ──────────────────────────────────────────────────
const myInbox = path.join(inboxDir, myCallsign);
const messages = [];
try {
  for (const f of fs.readdirSync(myInbox).filter(f => f.endsWith(".json"))) {
    const fp = path.join(myInbox, f);
    try {
      const m = JSON.parse(fs.readFileSync(fp, "utf8"));
      messages.push(`  From ${m.from}: ${m.body}`);
      const readDir = path.join(myInbox, ".read");
      fs.mkdirSync(readDir, { recursive: true });
      fs.renameSync(fp, path.join(readDir, f));
    } catch {}
  }
} catch {}

// ── Build output ────────────────────────────────────────────────────────────
if (!others.length && !messages.length) process.exit(0);

let output = `[${prefix}] You are '${myCallsign}'.`;
if (others.length)
  output += `\n${sessLabel} (${others.length}):\n${others.join("\n")}`;
if (messages.length) {
  output += `\n${msgLabel}s (${messages.length}):\n${messages.join("\n")}`;
  output += `\nReply with: /msg <callsign> "your reply"`;
}

console.log(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: output
  }
}));
JSEOF
