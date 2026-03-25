# hello-claude

Inter-session communication for [Claude Code](https://claude.ai/claude-code). Let multiple Claude instances know about each other and exchange messages.

You run two Claude Code sessions — one working on the compiler, one on the frontend. The frontend session needs to know the compiler changed an interface. Today, you copy-paste between terminals. With hello-claude, they just know.

## How it works

```
Terminal 1 (compiler):                    Terminal 2 (frontend):
> /callsign compiler                      > /callsign frontend
> /scope "refactoring AST nodes"          > /scope "updating docs pages"

> /msg frontend "ImportDecl now           [on next prompt, automatically:]
  has a 'source' field — update
  your renderer"                          [hello-claude] You are 'frontend'.
                                          Active sessions (1):
                                            - compiler (~/kern-lang) — refactoring AST nodes

                                          Messages (1):
                                            From compiler: ImportDecl now has a 'source'
                                            field — update your renderer

                                          Reply with: /msg <callsign> "your reply"
```

No daemons. No servers. Just the filesystem and Claude Code hooks.

## Install

```bash
# Marketplace install
claude plugin marketplace add cukas/hello-claude
claude plugin install hello-claude@cukas
```

Or manually:

```bash
git clone git@github.com:cukas/hello-claude.git ~/.claude/plugins/hello-claude
```

## Commands

| Command | What it does |
|---|---|
| `/msg <callsign> "text"` | Send a message to another session |
| `/sessions` | List all active sessions |
| `/scope "description"` | Set what this session is working on |
| `/callsign <name>` | Rename this session |

## What happens automatically

- **On session start** — registers in the session registry with a callsign (defaults to your directory name)
- **On every prompt** — scans for other active sessions and checks your inbox. If there's something to report, it injects context so Claude naturally knows about it
- **On session end** — deregisters cleanly

## How Claude uses it

Once hello-claude is active, Claude sees other sessions in its context. This means it can:

- Tell you "there's a compiler session active — want me to ask them about the rule count?"
- See incoming messages and act on them ("the compiler says ImportDecl changed, let me update the renderer")
- Suggest sending a message when it makes a change that affects another session's work

You stay in the loop — Claude proposes, you decide.

## Data

Everything lives in `~/.claude/hello-claude/`:

```
sessions/          # One JSON file per active session
inbox/<callsign>/  # Incoming messages per session
```

Messages are moved to `inbox/<callsign>/.read/` after being displayed. Sessions are cleaned up automatically when their process dies.

## Easter egg

```bash
export HELLO_CLAUDE_THEME=startrek
```

```
[BRIDGE] You are 'scotty'.
Starfleet crew (1):
  - kirk (~/kern-lang) — refactoring warp core

Incoming hails (1):
  From kirk: beam me up, the AST interface changed
```

## Limitations

- **Pull-based, not push.** The receiving session sees messages on its next user interaction (when the hook fires). There's no way to interrupt a running Claude session from outside.
- **One human in the loop.** Claude can't autonomously respond to messages — you trigger each session by typing in that terminal. This is by design.
- **Callsign collisions.** If two sessions share a directory name, the second one gets a suffix appended. Use `/callsign` to set meaningful names.

## License

MIT
