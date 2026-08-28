#!/usr/bin/env bash
# Terminate foreground process group and descendant tree for a Herdr pane.
# Usage: kill-pane-processes.sh <pane_id> [--graceful]
set -euo pipefail

PANE="${1:-}"
GRACEFUL=0
if [[ "${2:-}" == "--graceful" ]]; then
  GRACEFUL=1
fi

if [[ -z "$PANE" ]]; then
  echo "usage: kill-pane-processes.sh <pane_id> [--graceful]" >&2
  exit 2
fi

json_field() {
  python3 -c '
import json, sys
d = json.load(sys.stdin)
key = sys.argv[1]
r = d.get("result", d)

def walk(obj, keys):
    if isinstance(obj, dict):
        for k in keys:
            if k in obj and obj[k] is not None and obj[k] != "":
                return obj[k]
        for v in obj.values():
            found = walk(v, keys)
            if found is not None and found != "":
                return found
    elif isinstance(obj, list):
        for v in obj:
            found = walk(v, keys)
            if found is not None and found != "":
                return found
    return ""

print(walk(r, (key,)) or "")
' "$1"
}

collect_pids() {
  python3 -c '
import json, sys
d = json.load(sys.stdin)
info = d.get("result", {}).get("process_info", d.get("process_info", {}))
pids = []
shell = info.get("shell_pid")
if shell:
    pids.append(int(shell))
pgid = info.get("foreground_process_group_id")
for proc in info.get("foreground_processes", []):
    pid = proc.get("pid")
    if pid:
        pids.append(int(pid))
print(" ".join(str(p) for p in sorted(set(pids))))
print(pgid or "", end="")
' 
}

kill_tree() {
  local pid="$1"
  local sig="$2"
  [[ -z "$pid" || "$pid" == "1" ]] && return 0
  if ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  local child
  while IFS= read -r child; do
    [[ -z "$child" ]] && continue
    kill_tree "$child" "$sig"
  done < <(pgrep -P "$pid" 2>/dev/null || true)
  kill "-$sig" "$pid" 2>/dev/null || kill "$sig" "$pid" 2>/dev/null || true
}

INFO="$(herdr pane process-info --pane "$PANE" 2>/dev/null || true)"
if [[ -z "$INFO" ]]; then
  echo "WARN: no process info for pane ${PANE}" >&2
  exit 0
fi

read -r PIDS PGID <<< "$(printf '%s\n' "$INFO" | collect_pids)"

if [[ "$GRACEFUL" -eq 1 ]]; then
  herdr pane send-keys "$PANE" ctrl+c 2>/dev/null || true
  sleep 0.5
fi

if [[ -n "$PGID" && "$PGID" != "0" && "$PGID" != "1" ]]; then
  echo "Sending TERM to process group -${PGID} (pane ${PANE})"
  kill -TERM "-${PGID}" 2>/dev/null || true
fi

for pid in $PIDS; do
  kill_tree "$pid" TERM
done

sleep 1

if [[ -n "$PGID" && "$PGID" != "0" && "$PGID" != "1" ]]; then
  kill -KILL "-${PGID}" 2>/dev/null || true
fi
for pid in $PIDS; do
  kill_tree "$pid" KILL
done

echo "OK: killed processes for pane ${PANE}"
