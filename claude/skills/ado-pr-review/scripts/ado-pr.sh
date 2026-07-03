#!/usr/bin/env bash
#
# ado-pr.sh — thin wrapper over the Azure DevOps PR-threads REST API.
#
# Org/project/repo are derived from the `origin` git remote so this works
# regardless of `az devops configure` defaults. Auth uses the active `az login`
# token (resource = Azure DevOps app id). Run `az login` first if it 401s.
#
# Subcommands:
#   list-threads <prId>
#       Print active (unresolved) threads as compact JSON lines:
#       {id,status,filePath,line,author,isClaudeReview,firstComment}
#
#   list-claude-threads <prId>
#       Same as list-threads but only threads whose first comment carries the
#       Claude-review marker AND are still active/unresolved. This is what the
#       monitor loop consumes.
#
#   comment <prId> <filePath> <line> <contentFile>
#       Open a NEW inline review thread on <filePath>:<line>. Body is read from
#       <contentFile>. The marker is prepended automatically. Used by the
#       review subagent.
#
#   comment-general <prId> <contentFile>
#       Open a NEW non-file (overview) thread. Marker prepended automatically.
#
#   reply <prId> <threadId> <contentFile>
#       Append a reply comment to an existing thread.
#
#   resolve <prId> <threadId> [status]
#       Set thread status (default: fixed). Valid: fixed|closed|wontFix|active.
#
#   show <prId>
#       Print PR title/status/url (sanity check).
#
set -euo pipefail

MARKER='[claude-ai-review]'
ADO_RESOURCE='499b84ac-1321-427f-aa17-267ca6975798'  # Azure DevOps app id
API='api-version=7.1'

die() { echo "ado-pr.sh: $*" >&2; exit 1; }

# --- derive org/project/repo from the origin remote -------------------------
remote_url="$(git config --get remote.origin.url || true)"
[ -n "$remote_url" ] || die "no origin remote found (run inside the repo)"

# https://Mojo-Soup@dev.azure.com/<org>/<project>/_git/<repo>
path="${remote_url#*dev.azure.com/}"
ORG_NAME="${path%%/*}"
rest="${path#*/}"
PROJECT_ENC="${rest%%/_git/*}"
REPO="${rest##*/_git/}"
REPO="${REPO%.git}"

urldecode() { printf '%b' "${1//%/\\x}"; }
PROJECT="$(urldecode "$PROJECT_ENC")"
ORG_URL="https://dev.azure.com/${ORG_NAME}"

# az rest needs the project URL-encoded in the path; PROJECT_ENC already is.
BASE="${ORG_URL}/${PROJECT_ENC}/_apis/git/repositories/${REPO}/pullRequests"

azrest() {
  # $1=method  $2=url  [$3=bodyFile]
  local method="$1" url="$2" body="${3:-}"
  if [ -n "$body" ]; then
    az rest --method "$method" --resource "$ADO_RESOURCE" --url "$url" \
      --headers "Content-Type=application/json" --body "@${body}"
  else
    az rest --method "$method" --resource "$ADO_RESOURCE" --url "$url"
  fi
}

# Build a thread-creation payload to a temp file; echoes the temp path.
build_thread_payload() {
  # $1=contentFile  [$2=filePath $3=line]
  local content_file="$1" file_path="${2:-}" line="${3:-}"
  local marked tmp
  tmp="$(mktemp)"
  # Prepend marker so the monitor can recognise Claude-authored threads.
  marked="$(printf '%s\n\n%s' "$MARKER" "$(cat "$content_file")")"
  if [ -n "$file_path" ] && [ -n "$line" ]; then
    jq -n --arg c "$marked" --arg f "$file_path" --argjson l "$line" '{
      comments: [ { parentCommentId: 0, content: $c, commentType: 1 } ],
      status: 1,
      threadContext: {
        filePath: $f,
        rightFileStart: { line: $l, offset: 1 },
        rightFileEnd:   { line: $l, offset: 1 }
      }
    }' > "$tmp"
  else
    jq -n --arg c "$marked" '{
      comments: [ { parentCommentId: 0, content: $c, commentType: 1 } ],
      status: 1
    }' > "$tmp"
  fi
  echo "$tmp"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  show)
    pr="${1:?prId required}"
    azrest GET "${BASE}/${pr}?${API}" \
      | jq '{pullRequestId, title, status, isDraft, url: ("'"$ORG_URL"'/'"$PROJECT_ENC"'/_git/'"$REPO"'/pullrequest/" + (.pullRequestId|tostring))}'
    ;;

  list-threads|list-claude-threads)
    pr="${1:?prId required}"
    only_claude=false
    [ "$cmd" = "list-claude-threads" ] && only_claude=true
    azrest GET "${BASE}/${pr}/threads?${API}" \
      | jq -c --arg marker "$MARKER" --argjson onlyClaude "$only_claude" '
        .value[]
        # active=1. Skip resolved (fixed=2, wontFix=3, closed=4) and deleted threads.
        | select(.status == "active" or .status == 1)
        | (.comments // [] | map(select(.isDeleted != true))) as $cs
        | select(($cs | length) > 0)
        | ($cs[0]) as $first
        | {
            id: .id,
            status: .status,
            filePath: (.threadContext.filePath // null),
            line: (.threadContext.rightFileStart.line // null),
            author: ($first.author.displayName // "unknown"),
            isClaudeReview: (($first.content // "") | contains($marker)),
            commentCount: ($cs | length),
            firstComment: (($first.content // "") | gsub("\n"; " ") | .[0:200])
          }
        | select($onlyClaude == false or .isClaudeReview == true)
      '
    ;;

  comment)
    pr="${1:?prId required}"; file="${2:?filePath required}"; line="${3:?line required}"; content="${4:?contentFile required}"
    payload="$(build_thread_payload "$content" "$file" "$line")"
    azrest POST "${BASE}/${pr}/threads?${API}" "$payload" | jq '{threadId: .id, status: .status}'
    rm -f "$payload"
    ;;

  comment-general)
    pr="${1:?prId required}"; content="${2:?contentFile required}"
    payload="$(build_thread_payload "$content")"
    azrest POST "${BASE}/${pr}/threads?${API}" "$payload" | jq '{threadId: .id, status: .status}'
    rm -f "$payload"
    ;;

  reply)
    pr="${1:?prId required}"; thread="${2:?threadId required}"; content="${3:?contentFile required}"
    tmp="$(mktemp)"
    jq -n --arg c "$(cat "$content")" '{ parentCommentId: 1, content: $c, commentType: 1 }' > "$tmp"
    azrest POST "${BASE}/${pr}/threads/${thread}/comments?${API}" "$tmp" | jq '{commentId: .id}'
    rm -f "$tmp"
    ;;

  resolve)
    pr="${1:?prId required}"; thread="${2:?threadId required}"; status="${3:-fixed}"
    # status string -> ADO enum int
    case "$status" in
      active)  s=1 ;;
      fixed)   s=2 ;;
      wontFix) s=3 ;;
      closed)  s=4 ;;
      pending) s=6 ;;
      *) die "invalid status: $status" ;;
    esac
    tmp="$(mktemp)"
    jq -n --argjson s "$s" '{ status: $s }' > "$tmp"
    azrest PATCH "${BASE}/${pr}/threads/${thread}?${API}" "$tmp" | jq '{threadId: .id, status: .status}'
    rm -f "$tmp"
    ;;

  env)
    # Debug: print derived connection details.
    printf 'org=%s\nproject=%s\nrepo=%s\nbase=%s\n' "$ORG_NAME" "$PROJECT" "$REPO" "$BASE"
    ;;

  *)
    die "unknown subcommand: '${cmd}'. See header for usage."
    ;;
esac
