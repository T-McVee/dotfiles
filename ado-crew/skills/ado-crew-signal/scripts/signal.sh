#!/usr/bin/env bash
# Deliver an ado-crew memo: write .ticket/HANDOFF.md, then Herdr 0.8 prompt --wait.
# Usage: signal.sh <target-agent> <TOKEN> <ADO> [body] [memo-file]
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: signal.sh <target-agent> <TOKEN> <ADO> [body] [memo-file]" >&2
  exit 2
fi

TARGET="$1"
TOKEN="$2"
ADO="$3"
BODY="${4:-}"
MEMO_FILE="${5:-}"
TICKET_DIR="${TICKET_DIR:-.ticket}"

MSG="${TOKEN}
ADO: ${ADO}
${BODY}"

mkdir -p "${TICKET_DIR}/handoffs"
{
  printf '%s\n' "$MSG"
  if [[ -n "$MEMO_FILE" && -f "$MEMO_FILE" ]]; then
    printf '\n'
    cat "$MEMO_FILE"
  fi
} > "${TICKET_DIR}/HANDOFF.md"

n=0
if compgen -G "${TICKET_DIR}/handoffs/*" > /dev/null; then
  n=$(find "${TICKET_DIR}/handoffs" -type f | wc -l | tr -d ' ')
fi
cp "${TICKET_DIR}/HANDOFF.md" "${TICKET_DIR}/handoffs/$(printf '%03d' $((n + 1)))-${TOKEN}.md"

if [[ -n "${BEAD:-}" ]] && command -v bd >/dev/null 2>&1; then
  bd note "$BEAD" "${TOKEN} — ${BODY}" 2>/dev/null || true
  bd dolt push 2>/dev/null || true
fi

if ! herdr agent prompt "$TARGET" "$MSG" --wait --timeout 60000; then
  echo "WARN: herdr agent prompt to ${TARGET} failed — ${TICKET_DIR}/HANDOFF.md is authoritative" >&2
fi

herdr notification show "${TOKEN} AB#${ADO}" --body "${BODY:0:200}" --sound request 2>/dev/null || true
