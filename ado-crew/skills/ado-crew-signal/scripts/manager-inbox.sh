#!/usr/bin/env bash
# Print this crew's manager inbox from .ticket/context/flags.md.
# Usage: manager-inbox.sh
# Fail closed if manager_inbox is missing. Do not default to "manager".
set -euo pipefail

TICKET_DIR="${TICKET_DIR:-.ticket}"
FLAGS="${TICKET_DIR}/context/flags.md"

if [[ ! -f "$FLAGS" ]]; then
  echo "ERROR: ${FLAGS} missing — cannot resolve manager inbox" >&2
  echo "Stop. Do not signal manager. Mail would hit whichever crew registered that name first." >&2
  exit 1
fi

INBOX="$(python3 -c '
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"(?m)^[ \t]*manager_inbox:[ \t]*(\S+)", text)
if not m:
    sys.exit(1)
print(m.group(1).strip(" \"'\''"))
' "$FLAGS" || true)"

if [[ -z "$INBOX" ]]; then
  echo "ERROR: manager_inbox missing from ${FLAGS}" >&2
  echo "Stop. Do not default to manager — that delivers mail to the wrong crew." >&2
  exit 1
fi

if ! [[ "$INBOX" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
  echo "ERROR: manager_inbox '${INBOX}' is not a valid Herdr agent name ([a-z][a-z0-9_-]{0,31})" >&2
  exit 1
fi

printf '%s\n' "$INBOX"
