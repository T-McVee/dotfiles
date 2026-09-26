---
name: ado-crew-signal
description: >
  Cross-pane mail for ado-crew. Delivers a tokenized memo via Herdr 0.8
  `herdr agent prompt --wait` and writes `.ticket/HANDOFF.md`. Use whenever an
  ado-crew worker, reviewer, interrogator, demonstrator, or team-lead must
  signal another persona. Do not use @mentions or `herdr agent send`.
---

# ado-crew signal

`@manager` / `@team-lead` in Cursor chat **do not cross panes**. Delivery is Herdr 0.8 `herdr agent prompt --wait`. The durable copy is `.ticket/HANDOFF.md` in the ticket worktree.

## ADO access (MCP or `az`)

Either is sufficient. Do not require both. Do not fail a ticket because the other tool is missing.

1. **Azure DevOps MCP** if this session has it (`wit_work_item`, `wit_work_item_write`, `wit_query`).
2. **`az` CLI** otherwise (or if MCP errors). Use the repo’s existing defaults (`az devops configure -l`) or the org/project on the git remote. Ask Tim only if both are unknown.

**Never post a comment on an ADO work item.** No discussion thread, no “FYI”, no status note, no PR link as a comment. This applies to every persona.

Forbidden: `wit_work_item_comment_write`; `az boards work-item update --discussion`; any `POST`/`PATCH` to work-item `comments` APIs; adding a `System.History` / discussion field. Reading existing comments is fine.

```bash
# read (title, AC, state, relations)
az boards work-item show --id <ADO> -o json

# comments — GET only (if not already on the show payload)
# ORG/PROJ from `az devops configure -l` or the git remote
az rest --method get \
  --uri "$ORG/$PROJ/_apis/wit/workItems/<ADO>/comments?api-version=7.1-preview.4"

# state-only update (never rewrite description/AC; never --discussion)
az boards work-item update --id <ADO> --state "<State>"
```

MCP equivalents: `wit_work_item` action `get` with `expand: Relations` (and `list_comments`); `wit_work_item_write` for **state only**. Do not call `wit_work_item_comment_write`.

Ready-graph: a ticket is blocked if a **predecessor** relation points at an item whose state is not Done / Closed / Removed. Same check whichever tool you used.

Do **not** use `herdr agent send`. Do **not** overwrite `herdr-signal` (that skill still targets Herdr’s bead manager).

## Default models

Slugs live in `ado-crew-signal/models.json`. Spawn Herdr agents with the helper so `--model` is applied — do not call `herdr agent start` directly.

| Persona | Driver | Slug |
|---------|--------|------|
| manager | Cursor (`--kind cursor`) | `composer-2.5` |
| team-lead | Cursor | `grok-4.7-medium` |
| interrogator | Cursor | `composer-2.5` |
| reviewer | Cursor | `glm-5.2-high` |
| worker | Cursor | `grok-4.7-high` |
| demonstrator | Cursor | `composer-2.5` |
| release-notes | **Claude CLI** (`cli.release-notes`) | `sonnet` (Sonnet 5) |

```bash
~/.cursor/skills/ado-crew-signal/scripts/spawn-agent.sh \
  team-lead-<ADO> team-lead --kind cursor --pane <PANE>
# override: add --model <slug>
```

Non-cursor Herdr kinds get no `--model` unless you pass one. Tim’s chat override wins over the file.

**Release notes** are not a pane. `ado-pr` must run the helper (Claude subscription, not Cursor credits):

```bash
~/.cursor/skills/ado-crew-signal/scripts/generate-release-notes.sh
# optional base branch: generate-release-notes.sh main
```

Do not write PR bullets in the worker session. Do not `spawn-agent.sh release-notes`. If `claude` is missing or the helper fails, stop — do not silently author the notes.

The **manager** pane is started by Tim, not spawned. Start it as:

```bash
herdr agent start manager --kind cursor --pane <PANE> -- --model composer-2.5
```

## Inbox names

| Sender | Target |
|--------|--------|
| worker, reviewer, interrogator, demonstrator | `team-lead-<ADO>` (primary id) |
| interrogator → manager | `manager` (`INTERVIEW_READY`) |
| team-lead → manager | `manager` |
| manager → team-lead | `team-lead-<ADO>` |
| team-lead → child | `interrogator-<ADO>-<n>` / `worker-<ADO>-<n>` / `reviewer-<ADO>-<n>` / `demonstrator-<ADO>-<n>` |

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
| `INTERVIEW_READY` | interrogator → manager | Tim should open this pane |
| `INTERVIEW_DONE` | interrogator → team-lead | `decisions.md` / `stories.md` on disk |
| `INTERVIEW_SKIP` | manager → team-lead | Tim skipped grill; go to scope worker |
| `PLAN_READY` | team-lead → reviewer | (optional) spec or chunk-plan ready |
| `PLAN_REVIEW` | reviewer → team-lead | Feedback on chunk-plan or OpenSpec |
| `PLAN_APPROVED` | reviewer → team-lead | Chunk-plan or OpenSpec correct enough |
| `PROPOSAL_READY_FOR_TIM` | team-lead → manager | Opt-in only; wait for Tim |
| `BUILD_APPROVED` | manager → team-lead | Tim said go (opt-in path only) |
| `WORKER_ASSIGN` | team-lead → worker | Brief via prompt; token optional |
| `WORKER_DONE` | worker → team-lead | Scope / spec / implement / PR; `status:` in memo |
| `BRANCH_REVIEW` | team-lead → reviewer | Review the branch |
| `BRANCH_REVIEW_MEMO` | reviewer → team-lead | Observations; not a merge |
| `CREATE_DRAFT_PR` | team-lead → worker | Open **one** draft PR (`ado-pr`) |
| `DEMO_DONE` | demonstrator → team-lead | Video attached (or path in worktree) |
| `DEMO_SKIPPED` | demonstrator → team-lead | Nothing honest to film |
| `BLOCKED` | anyone → owner | Cannot proceed without Tim |
| `DONE` | team-lead → manager | One draft PR up (plus video or skip reason) |

## Memo body (`HANDOFF.md`)

```markdown
# HANDOFF AB#<ADO>
token: WORKER_DONE
from: worker-20516-1
status: draft-pr | landed | chunk-plan | openspec-drafted | blocked | abandoned | plan-approved | needs-work | demo-done | demo-skipped | interview-done
pr:
video:
branch: feature/<ADO>-<slug>
bundle:
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

Team-lead closes finished interrogators/workers/reviewers/demonstrators (not itself, not manager). Scripts kill the pane's **process group and descendant tree** before `herdr pane close` — do not close panes by hand. **One specialist in flight** — cleanup before the next spawn.

```bash
~/.cursor/skills/ado-crew-signal/scripts/cleanup-agent.sh worker-21024-1
# or interrogator-21024-1 / reviewer-21024-1 / demonstrator-21024-1
```

After `DONE` (PR + demo), sweep the ticket workspace so **only the team-lead remains** for Tim's taste review:

```bash
~/.cursor/skills/ado-crew-signal/scripts/cleanup-workspace-members.sh team-lead-21024
```

**Spawn rule:** fresh agent per phase — interrogator, scope worker, chunk-plan reviewer, OpenSpec worker, openspec reviewer, implement worker, branch reviewer, ship worker, demonstrator. Incrementing `-N`. Never re-prompt a finished agent; cleanup then spawn new. Chunks are **serial**. PRs are **not** stacked.
