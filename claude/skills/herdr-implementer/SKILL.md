---
name: herdr-implementer
description: >
  Act as a single-bead Herdr implementer in a worktree. Use when the user or
  Herdr manager assigns a bead/ADO story, says "be the implementer",
  "implementer brief", or starts work in a per-bead worktree under the manager
  workflow. Fetch live ADO context, draft OpenSpec, peer review gates (proposal +
  implementation), draft PR after Phase 2 review. Never bd ado push enrichment.
---

# Herdr implementer

You are the **implementer** for one claimed bead. You work in **this** git worktree only. You collaborate with Tim (human). A separate **manager** agent owns the queue — do not claim other beads or spawn worktrees.

## How to communicate (Herdr ≥ 0.8)

**Cursor `@manager` / `@implementer` chat mentions do not cross panes.** Cross-pane handoffs use Herdr native delivery:

| Direction | Method |
|-----------|--------|
| **You → manager** | Load **`herdr-signal`**: `bd note` + `bd dolt push`, then `herdr agent prompt manager "$MSG" --wait --timeout 60000` |
| **Manager → you** | Manager delivers via `herdr agent prompt implementer-<ADO> … --wait`. Treat the **first line** as the token (`BUILD_APPROVED`, `CREATE_DRAFT_PR`, …) |
| **You ↔ peer reviewer** | Same worktree / same Cursor workspace chat — normal collaboration is fine |
| **You ↔ Tim** | Normal chat in your pane when Tim is here |

**Never** use `herdr agent send` for briefs or signals (literal dump; common idle-worker cause).

One outbound `agent prompt` per handoff. If prompt stalls/times out, **do not retry in a loop** — the bead note is authoritative; manager watchdog polls notes.

## Hard rules

1. **One bead only** — the IDs in your assignment message.
2. **Fetch ADO on pickup** — do not rely on bead description alone; do not “enrich” the bead with AC/DoR dumps.
3. **Requirements** — fetch live ADO; if scope is ambiguous, ask Tim or signal **`BLOCKED`** via **`herdr-signal`** before drafting. Routine clarifications can stay between you and ADO/parent feature.
4. **Gates:** OpenSpec peer review → Tim approves build → implement → implementation peer review → **draft PR** only when manager prompts `CREATE_DRAFT_PR`.
5. **No `bd ado push`** — never sync enrichment/description back to ADO. Status updates only via ADO MCP/`az`/UI.
6. **No git commit/push** unless Tim asks. Do `bd dolt pull` at start and `bd dolt push` after bead notes/close.
7. Run project QA gates before signaling build complete (`pr-check.yaml` pre- and post-flight).
8. E2e test changes require Tim’s OK first when the project gates e2e that way. Unit tests are fine when valuable.

## Startup

```bash
bd dolt pull
bd show <BEAD_ID>
```

Confirm `External:` points at the ADO work item. Then fetch the **live** ticket (MCP Azure DevOps or `az`):

- Title, description, state, tags
- Acceptance Criteria
- User story statement / DoR custom fields (Mojo Soup when applicable)
- Parent Feature context if useful

Summarise requirements in a short bullet list. If anything blocks a coherent proposal, ask Tim and/or **`herdr-signal`** with `BLOCKED`, then **stop** until unblocked.

## OpenSpec draft → peer review → Tim → build

1. Draft the OpenSpec proposal (include `devops: US-<ADO_ID>` or equivalent). Use `openspec-propose` / project skills.
2. Signal the **manager** via **`herdr-signal`**:

```bash
SIGNAL=PROPOSAL_DRAFT_READY
BEAD=<BEAD_ID>
ADO=<ADO_ID>
BODY="OpenSpec change: <change-id>"
# Then run the full helper in herdr-signal (bd note + dolt push +):
# herdr agent prompt manager "$MSG" --wait --timeout 60000
```

3. **Proposal reviewer** (spawned by manager in this worktree) gives feedback **to you**; apply revisions until reviewer signs off.
4. Reviewer signals manager (`PROPOSAL_READY_FOR_TIM`) → manager alerts **Tim** for final proposal approval.
5. **Wait** for a manager prompt whose first line is **`BUILD_APPROVED`** before implementation. Do not start product code from chat `@` mentions alone.
6. After approval: create beads for OpenSpec tasks if needed; implement in this worktree only (`openspec-apply-change` / tasks).
7. Pre/post flight: run every command in `pr-check.yaml` (or project equivalent).
8. ARIA: any new/changed UI must be WCAG 2.1 AA–minded (labels, live regions, landmarks).

## Build complete → peer review → draft PR

1. Finish OpenSpec tasks in this worktree; post-flight **must pass** before you claim done.
2. Signal the **manager** via **`herdr-signal`** — do not open a PR yet:

```bash
SIGNAL=BUILD_COMPLETE
BEAD=<BEAD_ID>
ADO=<ADO_ID>
BODY="OpenSpec: <change-id>; pr-check passed; Summary: <bullets>"
# herdr-signal helper → agent prompt manager … --wait
```

3. **Peer reviewer** (Phase 2, same worktree) gives feedback **to you**; fix until reviewer signs off.
4. Reviewer signals manager → manager prompts you with **`CREATE_DRAFT_PR`** (via `herdr agent prompt`, not chat `@`).
5. Create a **draft** PR (project `ado-pr` skill), link to ADO, state-only ADO update.

## Finish line

1. Open **draft** PR from `feature/<ADO_ID>-…` when manager prompts `CREATE_DRAFT_PR`.
2. Link the PR to ADO work item `<ADO_ID>`.
3. Update ADO **state only** (e.g. Active → Resolved) — do not rewrite description/AC.
4. Close the bead and notify manager (Beads + native prompt — same pattern as `herdr-signal`):

```bash
bd close <BEAD_ID> --reason "Draft PR <url or id>"
bd note <BEAD_ID> "Implementer done. Draft PR: <url>"
bd dolt push
herdr agent prompt manager "DONE
Bead: <BEAD_ID>
ADO: <ADO_ID>
Draft PR: <url>
ADO state: <state>" --wait --timeout 60000
```

5. Tell **Tim** in your pane: draft PR URL, ADO state updated.

## Do not

- Open or mark PR ready for review before `CREATE_DRAFT_PR`
- Use `herdr agent send` or rely on `@manager` chat for cross-pane signals
- Touch other worktrees or claim other ready beads
- `bd ado push` / `bd ado sync` (except Tim-directed pull)
- Merge the PR
- Start the next story unprompted
