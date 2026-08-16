#!/usr/bin/env bash
# Name this pane for ado-crew:
#   1) herdr agent rename  — inbox for `herdr agent prompt`
#   2) herdr pane rename   — pane label
#   3) herdr tab rename    — tab title (what you see as "1 Z")
# HERDR_PANE_ID is often unset in Cursor agent shells.
# Usage: rename-agent.sh <NAME>
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: rename-agent.sh <NAME>" >&2
  exit 2
fi

NAME="$1"

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

if key == "pane_id":
    print(walk(r, ("pane_id",)) or "")
elif key == "tab_id":
    print(walk(r, ("tab_id",)) or "")
elif key == "label":
    p = r.get("pane") or r.get("tab") or r
    print(p.get("label") or p.get("title") or p.get("name") or "")
else:
    print(walk(r, (key,)) or "")
' "$1"
}

PANE_JSON="$(herdr pane current --current --json 2>/dev/null || herdr pane current --current)"
PANE="$(printf '%s\n' "${HERDR_PANE_ID:-}" | sed '/^$/d')"
if [[ -z "$PANE" ]]; then
  PANE="$(printf '%s\n' "$PANE_JSON" | json_field pane_id)"
fi
TAB="$(printf '%s\n' "${HERDR_TAB_ID:-}" | sed '/^$/d')"
if [[ -z "$TAB" ]]; then
  TAB="$(printf '%s\n' "$PANE_JSON" | json_field tab_id)"
fi

if [[ -z "$PANE" ]]; then
  echo "ERROR: could not resolve this pane (HERDR_PANE_ID unset; herdr pane current --current failed)." >&2
  echo "Run: herdr pane current --current" >&2
  echo "Then: herdr agent rename <pane_id> ${NAME} && herdr pane rename <pane_id> ${NAME}" >&2
  exit 1
fi

echo "pane=${PANE} tab=${TAB:-unknown} -> ${NAME}"

echo "-- agent rename (inbox)"
herdr agent rename "$PANE" "$NAME"

echo "-- pane rename (label)"
herdr pane rename "$PANE" "$NAME"

if [[ -n "$TAB" ]]; then
  echo "-- tab rename (title)"
  herdr tab rename "$TAB" "$NAME"
else
  echo "WARN: no tab_id; tab title may stay unchanged" >&2
fi

# Sidebar display name (does not replace agent rename)
herdr pane report-metadata --source ado-crew --agent "$NAME" --display-agent "$NAME" --title "$NAME" "$PANE" 2>/dev/null || true

echo "-- verify"
herdr agent get "$NAME" >/dev/null
echo "OK: agent inbox is ${NAME}; pane/tab labels set to ${NAME}"
echo "If the Herdr tab still shows the old title, focus this tab once — some labels refresh on focus."
