#!/usr/bin/env bash
# Close every pane in the team-lead's workspace except the team-lead itself.
# Use after DONE (PR + demo) so only the team-lead remains for taste review.
# Usage: cleanup-workspace-members.sh <team-lead-name>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ $# -lt 1 ]]; then
  echo "usage: cleanup-workspace-members.sh <team-lead-name>" >&2
  exit 2
fi

TEAM_LEAD="$1"
case "$TEAM_LEAD" in
  team-lead-*)
    ;;
  *)
    echo "ERROR: expected team-lead-<ADO>, got ${TEAM_LEAD}" >&2
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

GET="$(herdr agent get "$TEAM_LEAD" 2>/dev/null || true)"
if [[ -z "$GET" ]]; then
  echo "ERROR: no live agent named ${TEAM_LEAD}" >&2
  exit 1
fi

KEEP_PANE="$(printf '%s\n' "$GET" | json_field pane_id)"
WORKSPACE="$(printf '%s\n' "$GET" | json_field workspace_id)"

if [[ -z "$KEEP_PANE" || -z "$WORKSPACE" ]]; then
  echo "ERROR: could not resolve pane/workspace for ${TEAM_LEAD}" >&2
  printf '%s\n' "$GET" >&2
  exit 1
fi

echo "Sweeping workspace ${WORKSPACE}; keeping ${TEAM_LEAD} pane=${KEEP_PANE}"

AGENT_LIST="$(herdr agent list 2>/dev/null || true)"
if [[ -n "$AGENT_LIST" ]]; then
  while IFS= read -r AGENT_NAME; do
    [[ -z "$AGENT_NAME" ]] && continue
    [[ "$AGENT_NAME" == "$TEAM_LEAD" ]] && continue
    echo "Closing agent ${AGENT_NAME}"
    "${SCRIPT_DIR}/cleanup-agent.sh" "$AGENT_NAME" || true
  done < <(printf '%s\n' "$AGENT_LIST" | python3 -c '
import json, sys
d = json.load(sys.stdin)
workspace = sys.argv[1]
keep_pane = sys.argv[2]
for agent in d.get("result", {}).get("agents", []):
    if agent.get("workspace_id") != workspace:
        continue
    if agent.get("pane_id") == keep_pane:
        continue
    name = agent.get("name")
    if name:
        print(name)
' "$WORKSPACE" "$KEEP_PANE")
fi

PANE_LIST="$(herdr pane list --workspace "$WORKSPACE" 2>/dev/null || true)"
if [[ -n "$PANE_LIST" ]]; then
  while IFS= read -r PANE_ID; do
    [[ -z "$PANE_ID" ]] && continue
    echo "Closing pane ${PANE_ID}"
    "${SCRIPT_DIR}/kill-pane-processes.sh" "$PANE_ID" --graceful || true
    herdr pane close "$PANE_ID" 2>/dev/null || true
  done < <(printf '%s\n' "$PANE_LIST" | python3 -c '
import json, sys
d = json.load(sys.stdin)
keep = sys.argv[1]
for p in d.get("result", {}).get("panes", []):
    pid = p.get("pane_id", "")
    if pid and pid != keep:
        print(pid)
' "$KEEP_PANE")
fi

echo "OK: workspace ${WORKSPACE} swept — ${TEAM_LEAD} remains"
