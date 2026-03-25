# hello-claude

Talk to another project's Claude. That's it.

```
/hello kern-lang what's the current rule count?
```

A Claude spins up in that project, reads the code, answers your question, and you're back to work. No switching terminals.

## How it works

```
You (in kern-lang-landing):

> /hello kern-lang did you change the ImportDecl interface?

[hello-claude] Asking kern-lang...

Yes, ImportDecl now has a 'source' field (added in commit a3f91b2).
The field is optional and defaults to null for backward compatibility.
```

Under the hood: `claude -p --cwd ~/GitHub/kern-lang "your question"`. If there's a live Claude session in that project, it gets a copy of your message too.

## Install

```bash
claude plugin marketplace add cukas/hello-claude
claude plugin install hello-claude@cukas
```

Or manually:

```bash
git clone git@github.com:cukas/hello-claude.git ~/.claude/plugins/hello-claude
```

## Setup

Register your projects (once):

```bash
/hello-setup kern-lang
/hello-setup landing ~/GitHub/kern-lang-landing
```

If the project lives in `~/GitHub/<name>`, the path is auto-detected.

## Commands

| Command | What it does |
|---|---|
| `/hello <project> <message>` | Ask another project's Claude something |
| `/hello-setup <name> [path]` | Register a project |

## Bonus: session awareness

If you run multiple Claude Code sessions, hello-claude also tracks them. Each session auto-registers on start, and a background hook shows you who else is active:

```
[hello-claude] You are 'kern-lang-landing'.
Active sessions (1):
  - kern-lang (~GitHub/kern-lang) — refactoring AST nodes
```

Extra commands for multi-session use:

| Command | What it does |
|---|---|
| `/msg <session> "text"` | Send a message to a live session's inbox |
| `/sessions` | List active sessions |
| `/scope "text"` | Describe what you're working on |
| `/callsign <name>` | Rename your session |

## Easter egg

```bash
export HELLO_CLAUDE_THEME=startrek
```

```
[BRIDGE] You are 'scotty'.
Starfleet crew (1):
  - kirk (~/kern-lang) — refactoring warp core

Incoming hails (1):
  From kirk: the AST interface changed
```

## Limitations

- **The spawned Claude is ephemeral.** It reads the project fresh each time — it doesn't have the context of a long-running session. For complex back-and-forth, use `/msg` with a live session instead.
- **Live session messages are pull-based.** The other session sees your `/msg` on their next interaction, not instantly.

## License

MIT
