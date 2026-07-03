#!/usr/bin/env bash
#
# cursor-review.sh — run an INDEPENDENT PR review using the Cursor CLI (`agent`)
# with GPT-5.5, then post its findings as inline ADO comments via ado-pr.sh.
#
# The reviewer runs read-only (`--mode ask`): it can read files but cannot write
# or run shell commands. Each round returns a JSON array of findings; THIS script
# posts them, so the [claude-ai-review] marker and comment formatting stay
# centralised.
#
# THOROUGHNESS — loop-until-dry: the reviewer is re-run, each round told which
# issues were already flagged, and asked only for NEW ones. It stops after
# DRY_STOP consecutive rounds that surface nothing new (default 2), or after
# MAX_ROUNDS rounds (default 4), whichever comes first. Findings are accumulated
# and deduped by file+line, then posted once at the end.
#
# Usage:
#   cursor-review.sh <prId> [model]
#       model defaults to gpt-5.5-high. Run `agent --list-models` for options.
#
# Env:
#   DRY_RUN=1     print findings but do not post any comments.
#   MAX_ROUNDS=N  cap on review rounds (default 4).
#   DRY_STOP=N    consecutive empty rounds that end the loop (default 2).
#
# Requires: agent (Cursor CLI), jq, and a logged-in Cursor session.
set -euo pipefail

PR_ID="${1:?prId required}"
MODEL="${2:-gpt-5.5-high}"
MAX_ROUNDS="${MAX_ROUNDS:-4}"
DRY_STOP="${DRY_STOP:-2}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADO="$HERE/ado-pr.sh"

command -v agent >/dev/null || { echo "cursor-review.sh: 'agent' (Cursor CLI) not on PATH" >&2; exit 1; }
command -v jq    >/dev/null || { echo "cursor-review.sh: 'jq' not on PATH" >&2; exit 1; }

# --- gather the diff to embed in the prompt (deterministic; no reliance on the
#     reviewer's shell access) ------------------------------------------------
STAT="$(git diff main...HEAD --stat)"
DIFF="$(git diff main...HEAD)"

# Build the prompt for one round. $1 = bullet list of already-flagged findings
# (or "(none yet)"). Echoes the prompt text.
build_prompt() {
  local already="$1"
  cat <<EOF
You are an INDEPENDENT senior code reviewer for a pull request. You have no prior
context — review only what the diff shows. The repository is the current working
directory; you may read any file in it for context.

Base branch: main. Changed files (stat):
$STAT

Full diff (unified, main...HEAD):
$DIFF

REVIEW BAR — flag ONLY real, high-confidence problems:
- correctness bugs, broken or wrongly-removed logic, security issues, unsafe data
  handling, or test gaps where a removed guard now has NO coverage of new behavior.
DO NOT flag: pre-existing issues, style, formatting, naming nitpicks, missing docs,
or anything a linter/typechecker/compiler would catch.

ALREADY FLAGGED in previous rounds — do NOT repeat these; look for additional,
DISTINCT issues only. If you find nothing genuinely new, return an empty array.
$already

OUTPUT CONTRACT — reply with ONLY a single fenced \`\`\`json code block, nothing else.
It must contain a JSON array of NEW findings. Each finding:
  {"file":"<path relative to repo root, exactly as in the diff>",
   "line":<integer line number on the NEW/right side of the diff>,
   "comment":"<specific, actionable review comment; no emojis>"}
If there are no new issues, output an empty array: []
EOF
}

# Run one review round. $1 = already-flagged bullet list. Echoes a JSON array.
run_round() {
  local prompt envelope result arr
  prompt="$(build_prompt "$1")"
  envelope="$(agent -p --model "$MODEL" --output-format json --mode ask --trust "$prompt")"
  result="$(printf '%s' "$envelope" | jq -r '.result // empty')"
  [ -n "$result" ] || { echo "cursor-review.sh: empty result from agent." >&2; return 1; }
  # Strip ```json ... ``` fences if present, else use as-is.
  arr="$(printf '%s' "$result" | sed -n '/```json/,/```/p' | sed '/```/d')"
  [ -n "$arr" ] || arr="$result"
  if ! printf '%s' "$arr" | jq -e 'type == "array"' >/dev/null 2>&1; then
    echo "cursor-review.sh: round output was not a JSON array. Reviewer said:" >&2
    printf '%s\n' "$result" >&2
    return 1
  fi
  printf '%s' "$arr"
}

# --- loop-until-dry ---------------------------------------------------------
ACC='[]'          # accumulated findings
dry=0             # consecutive empty rounds
round=0

while [ "$round" -lt "$MAX_ROUNDS" ] && [ "$dry" -lt "$DRY_STOP" ]; do
  round=$((round + 1))
  already="$(printf '%s' "$ACC" | jq -r 'if length == 0 then "(none yet)" else (.[] | "- \(.file):\(.line) — \(.comment)") end')"
  echo "cursor-review.sh: round $round/$MAX_ROUNDS ($MODEL, read-only)..." >&2

  ROUND_JSON="$(run_round "$already")" || exit 1

  # New = round findings whose file+line is not already accumulated.
  NEW="$(jq -n --argjson acc "$ACC" --argjson r "$ROUND_JSON" '
    $r | map(select(. as $x | ($acc | any(.file == $x.file and .line == $x.line)) | not))')"
  NEW_COUNT="$(printf '%s' "$NEW" | jq 'length')"

  if [ "$NEW_COUNT" -eq 0 ]; then
    dry=$((dry + 1))
    echo "cursor-review.sh: round $round found 0 new (dry $dry/$DRY_STOP)." >&2
  else
    dry=0
    ACC="$(jq -n --argjson acc "$ACC" --argjson new "$NEW" '$acc + $new')"
    echo "cursor-review.sh: round $round found $NEW_COUNT new (total $(printf '%s' "$ACC" | jq 'length'))." >&2
  fi
done

COUNT="$(printf '%s' "$ACC" | jq 'length')"
echo "cursor-review.sh: $round round(s) done; $COUNT distinct finding(s)." >&2

if [ "$COUNT" -eq 0 ]; then
  echo "No issues found — nothing to post."
  exit 0
fi

# --- post each accumulated finding as an inline comment ---------------------
printf '%s' "$ACC" | jq -c '.[]' | while read -r f; do
  file="$(printf '%s' "$f" | jq -r '.file')"
  line="$(printf '%s' "$f" | jq -r '.line')"
  body="$(printf '%s' "$f" | jq -r '.comment')"
  tmp="$(mktemp)"; printf '%s' "$body" > "$tmp"
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] would comment on $file:$line — $body"
  else
    echo "posting comment on $file:$line ..." >&2
    "$ADO" comment "$PR_ID" "$file" "$line" "$tmp"
  fi
  rm -f "$tmp"
done

echo "cursor-review.sh: done ($COUNT finding(s))."
