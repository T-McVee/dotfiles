#!/usr/bin/env bash
# Print the default Cursor model slug for an ado-crew persona.
# Empty stdout (exit 0) when kind is not cursor, or the persona has no default.
# Usage: resolve-model.sh <persona> [kind]
# persona: manager | team-lead | reviewer | worker | demonstrator
#          (agent names like team-lead-20516 are accepted)
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: resolve-model.sh <persona> [kind]" >&2
  exit 2
fi

RAW="$1"
KIND="${2:-cursor}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_FILE="${ADO_CREW_MODELS:-${SCRIPT_DIR}/../models.json}"

case "$RAW" in
  manager) PERSONA=manager ;;
  team-lead*) PERSONA=team-lead ;;
  reviewer*) PERSONA=reviewer ;;
  worker*) PERSONA=worker ;;
  demonstrator*) PERSONA=demonstrator ;;
  *)
    echo "ERROR: unknown persona '${RAW}'" >&2
    exit 2
    ;;
esac

if [[ "$KIND" != "cursor" ]]; then
  exit 0
fi

if [[ ! -f "$MODELS_FILE" ]]; then
  echo "ERROR: models file missing: ${MODELS_FILE}" >&2
  exit 1
fi

python3 -c '
import json, sys
path, persona = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
print(data.get("models", {}).get(persona, ""))
' "$MODELS_FILE" "$PERSONA"
