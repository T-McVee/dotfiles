---
name: ado-crew-signal
description: >
  Cross-pane mail for ado-crew. Delivers a tokenized memo via Herdr 0.8
  `herdr agent prompt --wait` and writes `.ticket/HANDOFF.md`. Use whenever an
  ado-crew worker, reviewer, or team-lead must signal another persona. Do not
  use @mentions or `herdr agent send`.
---

# ado-crew signal

`@manager` / `@team-lead` in Cursor chat **do not cross panes**. Delivery is Herdr 0.8 `herdr agent prompt --wait`. The durable copy is `.ticket/HANDOFF.md` in the ticket worktree.

## ADO access (MCP or `az`)

Either is sufficient. Do not require both. Do not fail a ticket because the other tool is missing.

1. **Azure DevOps MCP** if this session has it (`wit_work_item`, `wit_work_item_write`, `wit_work_item_comment_write`, `wit_query`).
2. **`az` CLI** otherwise (or if MCP errors). Use the repo’s existing defaults (`az devops configure -l`) or the org/project on the git remote. Ask Tim only if both are unknown.

```bash
# read (title, AC, state, relations)
az boards work-item show --id <ADO> -o json

# comments (if not already on the show payload)
# ORG/PROJ from `az devops configure -l` or the git remote
az rest --method get \
  --uri "$ORG/$PROJ/_apis/wit/workItems/<ADO>/comments?api-version=7.1-preview.4"

# state-only update (never rewrite description/AC)
az boards work-item update --id <ADO> --state "<State>"
```

MCP equivalents: `wit_work_item` action `get` with `expand: Relations` (and `list_comments`); `wit_work_item_write` for state; `wit_work_item_comment_write` to leave a comment.

Ready-graph: a ticket is blocked if a **predecessor** relation points at an item whose state is not Done / Closed / Removed. Same check whichever tool you used.

Do **not** use `herdr agent send`. Do **not** overwrite `herdr-signal` (that skill still targets Herdr’s bead manager).

## Inbox names

| Sender | Target |
|--------|--------|
| worker, reviewer | `team-lead-<ADO>` |
| team-lead → manager | `manager` |
| manager → team-lead | `team-lead-<ADO>` |
| team-lead → worker / reviewer | `worker-<ADO>-<n>` / `reviewer-<ADO>-<n>` |

Names: `[a-z][a-z0-9_-]{0,31}`, unique among live agents.

`HERDR_PANE_ID` is often unset in Cursor agent shells. Never run `herdr agent rename "$HERDR_PANE_ID" …` when that variable is empty. The helper sets **three** names (inbox, pane label, tab title — the UI still showing `1 Z` means only the inbox was renamed):

```bash
~/.cursor/skills/ado-crew-signal/scripts/rename-agent.sh manager          # or team-lead-<ADO>
# herdr agent rename  +  herdr pane rename  +  herdr tab rename
```

## Send a signal

From the **ticket worktree** root:

```bash
# ~/.cursor/skills/ado-crew-signal/scripts/signal.sh <target> <TOKEN> <ADO> [body]
~/.cursor/skills/ado-crew-signal/scripts/signal.sh \
  team-lead-20516 WORKER_DONE 20516 \
  "pr-check passed; leftover: empty-state not in AC"
# optional 5th arg: path to a longer memo appended under the token header
```

Script writes `.ticket/HANDOFF.md` + `.ticket/handoffs/NNN-TOKEN.md`, then `herdr agent prompt <target> --wait`. If prompt fails, the files are authoritative — the inbox polls `.ticket/handoffs/`.

**One prompt per signal.** Do not retry in a loop on stall. Do not stack follow-ups.

Optional Beads log (not the ready-graph): if `BEAD` is set and `bd` works, the script appends a note.

## Tokens

| Token | From → to | Meaning |
|-------|-----------|---------|
| `PLAN_READY` | team-lead → reviewer | OpenSpec drafted; review plan |
| `PLAN_REVIEW` | reviewer → team-lead | Feedback on plan (not approved) |
| `PLAN_APPROVED` | reviewer → team-lead | Plan correct enough to build |
| `PROPOSAL_READY_FOR_TIM` | team-lead → manager | Opt-in only; wait for Tim |
| `BUILD_APPROVED` | manager → team-lead | Tim said go (opt-in path only) |
| `WORKER_ASSIGN` | team-lead → worker | Build this plan (via prompt brief; token optional) |
| `WORKER_DONE` | worker → team-lead | Landed on branch; memo in HANDOFF |
| `BRANCH_REVIEW` | team-lead → reviewer | Review the branch |
| `BRANCH_REVIEW_MEMO` | reviewer → team-lead | Observations; not a merge |
| `CREATE_DRAFT_PR` | team-lead → worker | Open draft PR (`ado-pr`) |
| `BLOCKED` | anyone → owner | Cannot proceed without Tim |
| `DONE` | team-lead → manager | Draft PR up or abandoned |

## Memo body (`HANDOFF.md`)

```markdown
# HANDOFF AB#<ADO>
token: WORKER_DONE
from: worker-20516-1
status: draft-pr | landed | blocked | abandoned | plan-approved | needs-work
pr:
branch: feature/<ADO>-<slug>
what-landed:
left:
guesses:
collides-with:
unblock:
```

Reviewer memos use the same file. `left` / `guesses` are load-bearing. Taste nits do not belong here.

## Watchdog

If you are an inbox and no prompt arrived:

```bash
ls -1t .ticket/handoffs | head
cat .ticket/HANDOFF.md
herdr agent list
```

Treat the newest handoff file as the signal.

## Cleanup

Team-lead closes finished workers/reviewers (not itself, not manager):

```bash
~/.cursor/skills/ado-crew-signal/scripts/cleanup-agent.sh worker-21024-1
```
