---
name: herdr-signal
description: >
  Signal the Herdr manager from an implementer or peer-reviewer pane. Use instead
  of @manager chat mentions — those do not cross panes/workspaces. Requires Herdr
  0.8+ (herdr agent prompt --wait).
---

# Herdr signal (inter-agent handoff)

**`@manager` in Cursor chat does not notify the manager agent.** Each Herdr pane is an isolated session. Use **Beads (durable) + `herdr agent prompt` (delivery)** so the manager can see handoffs.

Requires **Herdr ≥ 0.8** (`herdr agent prompt`). Do **not** use `herdr agent send` — it only dumps literal text and is a common cause of idle workers.

## Manager target

The manager pane must be named **`manager`** (once per Herdr session):

```bash
herdr agent rename <MANAGER_PANE_ID> manager
# e.g. herdr agent rename w4:pS manager
```

Names must match `[a-z][a-z0-9_-]{0,31}` and be unique among live agents.

## Signal helper (implementer / reviewer)

After any gate, run this block (replace variables). **Beads first**, then prompt:

```bash
SIGNAL="BUILD_COMPLETE"   # or PROPOSAL_DRAFT_READY, PROPOSAL_READY_FOR_TIM, IMPLEMENTATION_REVIEW_APPROVED, BLOCKED
BEAD="ddp-csfl"
ADO="21030"
BODY="OpenSpec: copy-to-future-financial-year; pr-check passed"

MSG="${SIGNAL}
Bead: ${BEAD}
ADO: ${ADO}
${BODY}"

# 1) Durable ledger (authoritative if prompt fails)
bd note "$BEAD" "$SIGNAL — $BODY"
bd dolt push

# 2) Deliver into manager (atomic prompt + Enter; wait briefly for intake)
herdr agent prompt manager "$MSG" --wait --timeout 60000 || \
  echo "WARN: agent prompt to manager failed — bead note is authoritative; Tim/manager should poll bd notes"

# 3) Optional attention cues
herdr notification show "${SIGNAL} US-${ADO}" --body "$BODY" --sound request

PANE=$(herdr pane current --current --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('result',d); print((r.get('pane') or r).get('pane_id',''))" 2>/dev/null)
if [ -n "$PANE" ]; then
  herdr pane report-agent "$PANE" --source herdr:workflow --agent "implementer-${ADO}" --state blocked --message "$SIGNAL" 2>/dev/null || true
fi
```

Rules:

- **One** `herdr agent prompt` per signal — never spam follow-ups (Cursor stacks and stalls).
- If the manager is mid-turn, `--wait` may return when that turn settles; still OK.
- If prompt returns `agent_prompt_stalled` / timeout → **do not retry in a loop**; the `bd note` is enough for the manager watchdog.

## Manager → worker (for reference)

When the **manager** briefs a worker, it should also use prompt/wait (see `herdr-manager`), not `agent send`:

```bash
herdr agent wait implementer-<ADO> --until idle --until done --timeout 60000
herdr agent prompt implementer-<ADO> "<single combined brief>" --wait --timeout 120000
```

## Manager pickup / watchdog

On session start and **periodically** while work is in flight (do not rely only on inbound prompts):

```bash
bd dolt pull
bd list --status=in_progress    # NOTES containing SIGNAL tokens
herdr agent list
herdr agent read implementer-<ADO_ID> --source recent-unwrapped --lines 40
```

Treat **`bd note` containing the SIGNAL token** as authoritative if `agent prompt` fails (manager not named, busy, stalled, etc.).

## Signal tokens

| Token | Sender | Manager action |
|-------|--------|----------------|
| `PROPOSAL_DRAFT_READY` | Implementer | Spawn peer reviewer Phase 1 |
| `PROPOSAL_READY_FOR_TIM` | Reviewer | Notify Tim for proposal approval |
| `BUILD_COMPLETE` | Implementer | Start peer reviewer Phase 2 |
| `IMPLEMENTATION_REVIEW_APPROVED` | Reviewer | `CREATE_DRAFT_PR` to implementer via `agent prompt` |
| `BLOCKED` | Anyone | Escalate to Tim |
| `DONE` | Implementer | Record draft PR URL / ADO state; free the slot |
