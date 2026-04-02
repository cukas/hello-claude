#!/usr/bin/env bash
# hello-claude — register a project alias
# Usage: hello-setup.sh <name> <path>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

NAME="${1:-}"
PROJECT_PATH="${2:-}"

if [[ -z "$NAME" ]]; then
  echo "Usage: /hello-setup <name> <path>" >&2
  echo "  /hello-setup kern-lang ~/GitHub/kern-lang" >&2
  echo "  /hello-setup landing ~/GitHub/kern-lang-landing" >&2
  exit 1
fi

# Auto-detect path if not given
if [[ -z "$PROJECT_PATH" ]] && [[ -d "${HOME}/GitHub/${NAME}" ]]; then
  PROJECT_PATH="${HOME}/GitHub/${NAME}"
fi

if [[ -z "$PROJECT_PATH" ]] || [[ ! -d "$PROJECT_PATH" ]]; then
  echo "ERROR: Directory not found. Provide the full path:" >&2
  echo "  /hello-setup ${NAME} /path/to/project" >&2
  exit 1
fi

# Resolve to absolute path
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

# Load or create projects.json
PROJECTS_FILE="${HC_DATA}/projects.json"

node -e "
  const fs = require('fs');
  const file = process.argv[1], name = process.argv[2], projPath = process.argv[3];
  let projects = {};
  try { projects = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
  projects[name] = projPath;
  fs.writeFileSync(file, JSON.stringify(projects, null, 2));
" "$PROJECTS_FILE" "$NAME" "$PROJECT_PATH"

echo "Registered: ${NAME} -> ${PROJECT_PATH}"
echo "Now you can: /hello ${NAME} what's the status?"
