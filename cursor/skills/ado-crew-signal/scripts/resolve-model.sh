#!/usr/bin/env bash
# Print the default model slug for an ado-crew persona.
# CLI personas (models.json "cli") always return their model, any kind.
# Herdr/Cursor personas: empty stdout (exit 0) when kind is not cursor.
# Usage: resolve-model.sh <persona> [kind]
# persona: manager | team-lead | reviewer | worker | demonstrator | interrogator | release-notes
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
  interrogator*) PERSONA=interrogator ;;
  release-notes*) PERSONA=release-notes ;;
  *)
    echo "ERROR: unknown persona '${RAW}'" >&2
    exit 2
    ;;
esac

if [[ ! -f "$MODELS_FILE" ]]; then
  echo "ERROR: models file missing: ${MODELS_FILE}" >&2
  exit 1
fi

CLI_MODEL="$(python3 -c '
import json, sys
path, persona = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
print((data.get("cli") or {}).get(persona, {}).get("model") or "")
' "$MODELS_FILE" "$PERSONA")"

if [[ -n "$CLI_MODEL" ]]; then
  printf '%s\n' "$CLI_MODEL"
  exit 0
fi

if [[ "$KIND" != "cursor" ]]; then
  exit 0
fi

python3 -c '
import json, sys
path, persona = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
print(data.get("models", {}).get(persona, ""))
' "$MODELS_FILE" "$PERSONA"
