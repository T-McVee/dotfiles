#!/usr/bin/env bash
# Start an ado-crew agent with the default Cursor model for its persona.
# Usage:
#   spawn-agent.sh <name> <persona> --kind <kind> --pane <id> [--model <slug>] [-- extra]
# persona: manager | team-lead | reviewer | worker | demonstrator
# --model on this command (or after --) overrides models.json.
# Non-cursor kinds get no --model unless you pass one.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ $# -lt 2 ]]; then
  echo "usage: spawn-agent.sh <name> <persona> --kind <kind> --pane <id> [--model <slug>] [-- extra]" >&2
  exit 2
fi

NAME="$1"
PERSONA="$2"
shift 2

KIND=""
PANE=""
OVERRIDE_MODEL=""
PASSTHRU=()
IN_PASSTHRU=0

while [[ $# -gt 0 ]]; do
  if [[ $IN_PASSTHRU -eq 1 ]]; then
    if [[ "$1" == "--model" && $# -ge 2 ]]; then
      OVERRIDE_MODEL="$2"
      shift 2
      continue
    fi
    PASSTHRU+=("$1")
    shift
    continue
  fi
  case "$1" in
    --kind)
      KIND="${2:-}"; shift 2 ;;
    --pane)
      PANE="${2:-}"; shift 2 ;;
    --model)
      OVERRIDE_MODEL="${2:-}"; shift 2 ;;
    --)
      IN_PASSTHRU=1; shift ;;
    *)
      echo "usage: spawn-agent.sh <name> <persona> --kind <kind> --pane <id> [--model <slug>] [-- extra]" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$KIND" || -z "$PANE" ]]; then
  echo "ERROR: --kind and --pane are required" >&2
  exit 2
fi

MODEL="${OVERRIDE_MODEL:-}"
if [[ -z "$MODEL" ]]; then
  MODEL="$("${SCRIPT_DIR}/resolve-model.sh" "$PERSONA" "$KIND" || true)"
fi

CMD=(herdr agent start "$NAME" --kind "$KIND" --pane "$PANE")
if [[ -n "$MODEL" || ${#PASSTHRU[@]} -gt 0 ]]; then
  CMD+=(-- )
  if [[ -n "$MODEL" ]]; then
    CMD+=(--model "$MODEL")
  fi
  if [[ ${#PASSTHRU[@]} -gt 0 ]]; then
    CMD+=("${PASSTHRU[@]}")
  fi
fi

echo "Starting ${NAME} persona=${PERSONA} kind=${KIND} model=${MODEL:-<kind default>}"
"${CMD[@]}"
