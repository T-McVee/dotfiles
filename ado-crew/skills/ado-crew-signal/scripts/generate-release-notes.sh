#!/usr/bin/env bash
# Generate PR release notes via Claude Code CLI (Sonnet 5).
# Not a Herdr pane. Prints markdown bullets to stdout.
# Writes .ticket/release-notes.md when .ticket exists.
# Usage: generate-release-notes.sh [base-branch]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_FILE="${ADO_CREW_MODELS:-${SCRIPT_DIR}/../models.json}"
SKILL_FILE="${SCRIPT_DIR}/../../ado-crew-release-notes/SKILL.md"
BASE="${1:-}"

if [[ ! -f "$SKILL_FILE" ]]; then
  SKILL_FILE="${HOME}/.cursor/skills/ado-crew-release-notes/SKILL.md"
fi
if [[ ! -f "$SKILL_FILE" ]]; then
  echo "ERROR: ado-crew-release-notes/SKILL.md not found" >&2
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude CLI not on PATH — release notes must be Sonnet 5 via Claude Code" >&2
  exit 1
fi

if [[ -z "$BASE" ]]; then
  if git rev-parse --verify --quiet main >/dev/null; then
    BASE=main
  elif git rev-parse --verify --quiet master >/dev/null; then
    BASE=master
  else
    echo "ERROR: could not resolve base branch (tried main, master)" >&2
    exit 1
  fi
fi

if [[ -z "$(git log "${BASE}..HEAD" --oneline --no-merges 2>/dev/null || true)" ]]; then
  echo "ERROR: no commits ahead of ${BASE}" >&2
  exit 1
fi

MODEL="$(python3 -c '
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
cli = data.get("cli", {}).get("release-notes", {})
print(cli.get("model") or "sonnet")
' "$MODELS_FILE")"
BIN="$(python3 -c '
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
cli = data.get("cli", {}).get("release-notes", {})
print(cli.get("bin") or "claude")
' "$MODELS_FILE")"

SYSTEM="$(cat "$SKILL_FILE")

You are the ado-crew release-notes persona. Follow the output contract exactly."

USER_PROMPT="$(cat <<EOF
Write release notes for the current branch vs ${BASE}.
Use only the git data below. Do not invent work that is not in the log or diff.

## git log ${BASE}..HEAD --oneline --no-merges

$(git log "${BASE}..HEAD" --oneline --no-merges)

## git log ${BASE}..HEAD --format=%s%n%b --no-merges

$(git log "${BASE}..HEAD" --format='%s%n%b' --no-merges)

## git diff ${BASE}...HEAD --stat

$(git diff "${BASE}...HEAD" --stat)

## git diff ${BASE}...HEAD

$(git diff "${BASE}...HEAD")
EOF
)"

echo "Generating release notes with ${BIN} --model ${MODEL} (base=${BASE})" >&2

TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

if ! "${BIN}" --print \
  --model "$MODEL" \
  --output-format text \
  --no-session-persistence \
  --permission-mode dontAsk \
  --permission-prompts none \
  --tools "" \
  --disable-slash-commands \
  --system-prompt "$SYSTEM" \
  "$USER_PROMPT" > "$TMP_OUT"; then
  echo "ERROR: ${BIN} failed — do not write release notes yourself" >&2
  exit 1
fi

NOTES="$(python3 -c '
import re, sys
text = sys.stdin.read().strip()
if not text:
    sys.exit("empty release notes from claude")
fence = re.match(r"^```(?:markdown|md)?\n(.*)\n```$", text, re.S)
if fence:
    text = fence.group(1).strip()
print(text)
' < "$TMP_OUT")"

if [[ -z "$NOTES" ]]; then
  echo "ERROR: empty release notes from ${BIN}" >&2
  exit 1
fi

printf '%s\n' "$NOTES"

if [[ -d .ticket ]]; then
  printf '%s\n' "$NOTES" > .ticket/release-notes.md
  echo "Wrote .ticket/release-notes.md" >&2
fi
