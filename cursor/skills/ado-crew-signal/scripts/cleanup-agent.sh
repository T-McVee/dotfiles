#!/usr/bin/env bash
# Close a finished ado-crew interrogator/worker/reviewer/demonstrator pane.
# Kills the pane's process group and descendant tree before closing.
# Usage: cleanup-agent.sh <agent-name>
# Does not close team-lead or manager.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ $# -lt 1 ]]; then
  echo "usage: cleanup-agent.sh <agent-name>" >&2
  exit 2
fi

NAME="$1"
case "$NAME" in
  manager|team-lead-*)
    echo "ERROR: refusing to close ${NAME}" >&2
    exit 2
    ;;
esac

json_field() {
  python3 -c '
import json, sys
d = json.load(sys.stdin)
key = sys.argv[1]
r = d.get("result", d)

def walk(obj, keys):
    if isinstance(obj, dict):
        for k in keys:
            if k in obj and obj[k]:
                return obj[k]
        for v in obj.values():
            found = walk(v, keys)
            if found:
                return found
    elif isinstance(obj, list):
        for v in obj:
            found = walk(v, keys)
            if found:
                return found
    return ""

print(walk(r, (key,)) or "")
' "$1"
}

GET="$(herdr agent get "$NAME" 2>/dev/null || true)"
if [[ -z "$GET" ]]; then
  echo "WARN: no live agent named ${NAME} — already gone?"
  exit 0
fi

PANE="$(printf '%s\n' "$GET" | json_field pane_id)"
if [[ -z "$PANE" ]]; then
  echo "ERROR: agent ${NAME} exists but pane_id missing" >&2
  printf '%s\n' "$GET" >&2
  exit 1
fi

echo "Cleaning up ${NAME} pane=${PANE}"
"${SCRIPT_DIR}/kill-pane-processes.sh" "$PANE" --graceful
herdr pane close "$PANE"
echo "OK: closed ${NAME}"
