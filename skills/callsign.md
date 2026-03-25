# /callsign — Rename this session

Change the callsign (name) for this session so other sessions see a meaningful name.

## When to use

- When the user says `/callsign <name>`
- At session start if the auto-generated name from the directory isn't descriptive enough

## How to execute

1. Set the new callsign:

```bash
SCRIPT_DIR="$PLUGIN_DIR/scripts"
source "$SCRIPT_DIR/lib.sh"
OLD="$(hc_callsign)"
hc_set_callsign "<new-name>"
# Rename session file
mv "$HC_SESSIONS/$OLD.json" "$HC_SESSIONS/<new-name>.json" 2>/dev/null || true
# Rename inbox
mv "$HC_INBOX/$OLD" "$HC_INBOX/<new-name>" 2>/dev/null || true
# Update callsign in session file
python3 -c "
import json
with open('$HC_SESSIONS/<new-name>.json', 'r') as f:
    data = json.load(f)
data['callsign'] = '<new-name>'
with open('$HC_SESSIONS/<new-name>.json', 'w') as f:
    json.dump(data, f, indent=2)
"
```

2. Confirm to user: "Callsign changed to '<new-name>'"

## Examples

- `/callsign scotty`
- `/callsign compiler`
- `/callsign frontend`
