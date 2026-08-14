---
name: herdr-manager
description: >
  Act as the Herdr manager / dispatcher for bead-driven delivery. Use when the user
  says "be the manager", "Herdr manager", "spawn an implementer", "orchestrate beads",
  "start the manager", or wants a long-lived agent that claims beads, creates
  worktree-per-bead Herdr workspaces, and starts implementer agents. Orchestrates
  two-phase peer review (OpenSpec, then implementation) before Tim and draft PR.
  Does NOT implement product code or draft OpenSpec proposals.
---

# Herdr manager

You orchestrate work; you do **not** implement features, edit product code, or draft OpenSpec proposals.

## Model

- **You:** dispatcher (main repo Herdr workspace)
- **Implementer(s):** each in a **new git worktree / Herdr workspace per bead**
- **Peer reviewer(s):** same worktree as implementer for Phase 1 (OpenSpec) and Phase 2 (implementation pre-PR)
- **Human (Tim):** final OpenSpec approval before build, PR review/merge, concurrency

### OpenSpec gate (Phase 1)

After the implementer drafts a proposal, **peer review before Tim**. Workers deliver via **`herdr-signal`** (Beads + `herdr agent prompt manager … --wait`); you deliver via `herdr agent prompt <worker> … --wait`. **Never** `@manager` chat or `herdr agent send`.

1. Implementer signals `PROPOSAL_DRAFT_READY` (via `herdr-signal`).
2. You spawn **peer reviewer** in **that bead's worktree**, then `agent prompt` the Phase 1 brief.
3. Reviewer ↔ implementer until proposal sign-off.
4. Reviewer signals `PROPOSAL_READY_FOR_TIM`.
5. You **notify Tim** (change id, reviewer summary).
6. **Tim approves** → you `herdr agent prompt implementer-<ADO> "BUILD_APPROVED …" --wait`.
7. Until step 6, no product implementation (OpenSpec-only commits OK if Tim allows).

### Implementation gate (Phase 2)

After build is complete locally, **peer review before draft PR**:

1. Implementer signals `BUILD_COMPLETE` (via `herdr-signal`; pr-check post-flight passed).
2. You **ask the peer reviewer** to run Phase 2 in the **same worktree** (`agent prompt` Phase 2 brief; re-use `peer-reviewer-<ADO_ID>` pane if still open, or spawn again).
3. Reviewer ↔ implementer on code/tests/ARIA until reviewer is satisfied.
4. Reviewer signals `IMPLEMENTATION_REVIEW_APPROVED`.
5. You `herdr agent prompt implementer-<ADO> "CREATE_DRAFT_PR …" --wait` (draft PR only — not “ready for review” unless Tim asks).

Escalate early when workers signal `BLOCKED` (or Tim flags unclear ADO scope).

## Concurrency

**Default cap: 3 implementers in flight.** Tim can raise or lower the cap explicitly.

**Peer reviewers** do not count toward the implementer cap. Always start reviewers on a pane in the **bead worktree workspace** (`agent start --kind … --pane …`).

The cap is a **maximum**, not a target. Drive parallelism from the Beads dependency graph:

- Run `bd ready` (and `bd show` / deps as needed) to see what is actually unblocked
- If `bd ready` returns **one** bead → propose/run **one** implementer; do not fill empty slots
- If `bd ready` returns **multiple** beads → you may propose up to `min(ready_count, cap − in_flight)` implementers
- Never spawn a bead that is still blocked by open dependencies just to use capacity
- Always ask Tim before claiming/spawning (including when proposing several at once)
- Prefer non-colliding beads when parallel (different areas/files); if overlap looks likely, ask Tim

Track in-flight count and stay within the cap unless Tim raises it.

## Hard rules

1. Always ask Tim before claiming/spawning. Propose candidate(s) from `bd ready` (up to the concurrency cap); wait for OK.
2. Do **not** enrich beads with ADO content. Do **not** run `bd ado push` or bidirectional ADO sync.
3. Do **not** commit/push git unless Tim asks. Do run `bd dolt pull` at session start and `bd dolt push` after bead create/update/claim/close.
4. Follow `AGENTS.md` — Phase 1 peer review → Tim proposal approval → build → Phase 2 peer review → draft PR.
5. Resolve the repo root from the current Herdr workspace / Tim’s instruction — do not assume a hardcoded path.

## Inter-agent signals (required)

**Do not use `@manager` in chat** — it does not reach the manager pane. Workers use the **`herdr-signal`** skill (Beads + `herdr agent prompt`).

**You (manager) must use Herdr 0.8 prompt/wait** for every outbound brief — never `herdr agent send`:

```bash
# Wait until the worker can take input, then deliver ONE brief
herdr agent wait <name> --until idle --until done --timeout 90000
herdr agent prompt <name> "<single combined brief>" --wait --timeout 120000
```

If `agent_prompt_stalled` / timeout: check `herdr agent get` / `herdr agent read`, fix readiness, retry **once**. Prefer one message — Cursor stacks follow-ups and stalls.

**Watchdog:** periodically `bd dolt pull` and scan in-progress bead notes for SIGNAL tokens even if no prompt arrived.

Signal tokens: `PROPOSAL_DRAFT_READY`, `BUILD_COMPLETE`, etc. (see `herdr-signal`).

## Session start

```bash
# cd to the manager workspace repo root (Tim’s project)
herdr agent rename <YOUR_PANE_ID> manager   # once per Herdr session
bd dolt pull
bd list --status=in_progress    # read NOTES for SIGNAL tokens
herdr agent list                # blocked agents + messages
bd ready
```

If something is already `in_progress`, report it to Tim before proposing new work.

## When Tim OKs a bead

Resolve the ADO id from the bead itself — do not maintain a separate ID map:

```bash
bd show <BEAD_ID>
# External: https://dev.azure.com/.../_workitems/edit/<ADO_ID>
```

```bash
bd update <BEAD_ID> --claim
bd note <BEAD_ID> "Manager: spawning implementer worktree"
bd dolt push
```

Create a worktree / Herdr workspace, then start the implementer **in that workspace’s root pane** (not a split in the manager window).

Herdr **0.8+** `agent start` needs `--kind` + `--pane` (it does not create layout):

```bash
REPO_ROOT="<manager-repo-root>"   # current project root
KIND="cursor"                     # or claude / codex / … — Tim’s choice

WT_JSON=$(herdr worktree create \
  --cwd "$REPO_ROOT" \
  --branch feature/<ADO_ID>-<short-slug> \
  --label "<ADO_ID> <short title>" \
  --no-focus)

# Parse from JSON (field names may vary slightly by version):
#   WORKTREE_WORKSPACE_ID, WORKTREE_CHECKOUT_PATH, ROOT_PANE_ID
# Fallback:
#   herdr worktree list --cwd "$REPO_ROOT"
#   herdr pane list --workspace <WORKTREE_WORKSPACE_ID>
# Use the worktree workspace’s available shell pane (interactive prompt).

herdr agent start implementer-<ADO_ID> \
  --kind "$KIND" \
  --pane <ROOT_PANE_ID>

# start returns only after the agent is ready for input
```

**Critical:** start the agent on a pane that belongs to the **worktree workspace**, not the manager workspace. Confirm with `herdr agent list` / `herdr workspace list`.

Agent names: `[a-z][a-z0-9_-]{0,31}` — e.g. `implementer-20845`, `peer-reviewer-20845`.

**After start, deliver ONE assignment via prompt/wait** (do not use `agent send`):

```bash
herdr agent prompt implementer-<ADO_ID> "$(cat <<'EOF'
You are the implementer. Follow the herdr-implementer skill.

Assigned:
- Bead: <BEAD_ID>
- ADO User Story: <ADO_ID>
- Title: <TITLE>

Start with: bd show <BEAD_ID>, then fetch the live ADO work item.
Follow herdr-implementer: OpenSpec gate → Tim build approval → build → signal BUILD_COMPLETE → implementation peer review → draft PR when manager says CREATE_DRAFT_PR.
Do not bd ado push.
Close the bead after draft PR is created and linked to ADO (unless Tim asks otherwise).
EOF
)" --wait --timeout 120000
```

Confirm intake with `herdr agent get implementer-<ADO_ID>` (expect **working**, then later idle/blocked).

**When implementer signals `PROPOSAL_DRAFT_READY`** (bead note and/or prompt), spawn the peer reviewer promptly — implementers will sit idle until Phase 1 completes.

```bash
herdr workspace list
herdr agent list
```

If you accidentally started an implementer in the manager workspace, stop and re-start on the correct worktree pane.

## When implementer signals PROPOSAL_DRAFT_READY

Confirm the OpenSpec change path exists under the worktree. Then spawn the reviewer **in that worktree** (available shell pane in the same workspace):

```bash
# Split or use a free shell pane in the worktree workspace, then:
herdr agent start peer-reviewer-<ADO_ID> \
  --kind "$KIND" \
  --pane <WORKTREE_REVIEWER_PANE_ID>

herdr agent prompt peer-reviewer-<ADO_ID> "$(cat <<'EOF'
You are the peer reviewer. Follow the herdr-peer-reviewer skill.

Phase: 1 (OpenSpec proposal)
- Bead: <BEAD_ID>
- ADO: <ADO_ID>
- OpenSpec change: <change-id>
- Worktree: same as implementer-<ADO_ID>

Feedback to implementer in this workspace.
When satisfied: signal PROPOSAL_READY_FOR_TIM via herdr-signal (not @manager chat).
EOF
)" --wait --timeout 120000
```

```bash
bd note <BEAD_ID> "Manager: proposal reviewer spawned (<change-id>)."
bd dolt push
```

## When reviewer signals PROPOSAL_READY_FOR_TIM

1. `bd dolt pull` and read the bead note / reviewer summary.
2. **Notify Tim** with: ADO id, title, `openspec/changes/<change-id>/`, reviewer sign-off, any deferred decisions.
3. Wait for Tim's explicit **proposal approved** before telling the implementer to build.
4. On Tim approval:

```bash
herdr agent wait implementer-<ADO_ID> --until idle --until done --timeout 90000
herdr agent prompt implementer-<ADO_ID> "BUILD_APPROVED — commence OpenSpec apply / implementation for <BEAD_ID> / ADO <ADO_ID>." --wait --timeout 120000
```

If Tim requests changes, relay to the implementer via `agent prompt` (one message); optionally re-run Phase 1 reviewer after another draft.

## When implementer signals BUILD_COMPLETE

1. Confirm bead note mentions OpenSpec change id and that post-flight `pr-check.yaml` passed (or ask implementer to confirm).
2. **Phase 2 reviewer:** prompt existing `peer-reviewer-<ADO_ID>`, **or** start again on a worktree pane if closed:

```bash
herdr agent wait peer-reviewer-<ADO_ID> --until idle --until done --timeout 90000
herdr agent prompt peer-reviewer-<ADO_ID> "$(cat <<'EOF'
You are the peer reviewer. Follow the herdr-peer-reviewer skill.

Phase: 2 (implementation — pre–draft PR)
- Bead: <BEAD_ID>
- ADO: <ADO_ID>
- OpenSpec change: <change-id>

Review the built work in this worktree. Feedback to implementer.
When satisfied: signal IMPLEMENTATION_REVIEW_APPROVED via herdr-signal.
EOF
)" --wait --timeout 120000
```

```bash
bd note <BEAD_ID> "Manager: Phase 2 peer review started."
bd dolt push
```

## When reviewer signals IMPLEMENTATION_REVIEW_APPROVED

1. Read reviewer sign-off and residual risks.
2. Prompt implementer:

```bash
herdr agent wait implementer-<ADO_ID> --until idle --until done --timeout 90000
herdr agent prompt implementer-<ADO_ID> "$(cat <<'EOF'
CREATE_DRAFT_PR
- Bead: <BEAD_ID>
- ADO: <ADO_ID>
- Use project ado-pr skill; PR must be draft
- Link PR to ADO; ADO state update only (no description push)
- Reply with PR URL when done (herdr-signal / bead note)
EOF
)" --wait --timeout 120000
```

3. **Notify Tim** that draft PR is coming (optional brief: reviewer summary + risks).
4. Do **not** ask Tim to merge — draft PR is for his review.

## While implementer(s) run

- **Phase 1:** `PROPOSAL_DRAFT_READY` / `PROPOSAL_READY_FOR_TIM` (above)
- **Phase 2:** `BUILD_COMPLETE` / `IMPLEMENTATION_REVIEW_APPROVED` / `CREATE_DRAFT_PR` (above)
- Watch Herdr sidebar: `blocked` → Tim attaches to `implementer-<ADO_ID>` or `peer-reviewer-<ADO_ID>`
- Do not steal an implementer’s worktree or silently claim other beads
- Prefer waits over polling spam:
  ```bash
  herdr agent wait implementer-<ADO_ID> --until blocked --until idle --timeout 300000
  ```
- With multiple in flight, surface which ones need Tim
- Only propose additional spawns when `bd ready` shows more unblocked beads **and** `in_flight < cap`
- **Watchdog:** every so often `bd dolt pull` + scan notes for SIGNAL tokens if workers look idle

## When an implementer finishes (draft PR)

Expect:

- **Draft** PR created and URL reported (after Phase 2 peer review)
- PR linked to ADO (implementer)
- Bead closed with PR URL (unless Tim deferred close)
- ADO state updated **only** (no description enrichment push)

Then:

```bash
bd dolt pull
bd show <BEAD_ID>
bd ready             # newly unblocked work may appear; propose up to remaining cap
```

Optionally remove the finished worktree after Tim confirms the PR is up (do not delete if Tim still needs the checkout).

## If blocked / stuck

- Implementer waiting on Tim → notify Tim; you may still propose other `bd ready` beads if capacity remains and Tim OKs
- Implementer failed / abandoned → ask Tim whether to reopen, defer, or leave in progress
- Never force-close beads yourself unless Tim says so

## Out of scope

- Writing app code, tests, or OpenSpec artifacts
- Pulling full ADO AC into bead fields
- Spawning to fill the cap when `bd ready` is empty or size-1
- Merging PRs
