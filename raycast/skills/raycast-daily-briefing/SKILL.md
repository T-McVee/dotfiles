---
name: raycast-daily-briefing
description: Morning briefing from Raycast. Snapshot the pinned Raycast Daily note into the Obsidian inbox, run the vault daily-briefing (which may wrap yesterday), derive a slim Today card into outbox, then replace the same Raycast Daily note. Use when the user says "/daily-briefing", "daily briefing", "brief me", "start my day", or wants the Raycast Daily note refreshed from the second brain. Requires Raycast Notes tools. Do not use for project-note dumps or a full inbox sync.
---

# Raycast Daily Briefing

Orchestrates the morning loop between Raycast Notes and the Obsidian second brain. One pinned Raycast note named **Daily note** is overwritten in place. Dated history lives in the vault.

This skill owns Raycast I/O. The vault skills stay filesystem-only.

## Paths

- **Second brain root:** `/Users/tim/Documents/Obsidian`
- **Vault:** `/Users/tim/Documents/Obsidian/notes`
- **Inbox:** `/Users/tim/Documents/Obsidian/inbox`
- **Outbox:** `/Users/tim/Documents/Obsidian/outbox`
- **Vault daily notes:** `notes/daily-note/YYYY-MM-DD.md` (current month); archives in `notes/daily-note/YYYY-MM/`
- **Vault briefing skill:** `/Users/tim/Documents/Obsidian/.claude/skills/daily-briefing/SKILL.md`
- **Vault wrap skill:** `/Users/tim/Documents/Obsidian/.claude/skills/daily-wrap/SKILL.md`
- **State file:** `/Users/tim/.claude/skills/raycast-daily-briefing/state.md`

Today's date comes from system context (`currentDate`). Never infer the weekday from the date — run `date +%A` if needed.

## Hard rules

1. Snapshot **before** wrap, briefing, or Raycast replace. That is what makes a missed EOD wrap recoverable.
2. This loop moves **one** Raycast note: the pinned Daily note. Do not dump DDP / TODO MAIN / DevCop here.
3. Inbox files are dated and append-only. Never overwrite `inbox/daily-note-YYYY-MM-DD.md` with today's slim card.
4. Vault Briefing / Learning never round-trip through Raycast.
5. Raycast replace is **last**, and only after step 1 succeeded (or confirmed the H1 date was already today).
6. Re-run the same morning: if the Raycast H1 is already today, skip yesterday snapshot; refresh outbox from the vault daily; do not clobber a processed inbox receipt.
7. If Raycast Notes tools are unavailable, stop. Do not invent a Daily note body.

## State file

Create `state.md` if missing:

```markdown
## Raycast Daily note
noteId:
title: Daily note
createdAt:
```

After the first successful `create-note`, persist `noteId`. Every later send is a replace of that id. Never create a second Daily note if `noteId` is set.

---

## Step 1 — Snapshot Raycast Daily note → inbox

1. Read `state.md`. If `noteId` is empty, search Raycast Notes for a note titled `Daily note` (or `Today`).
   - Found → write `noteId` to state, continue.
   - Not found → there is nothing to snapshot. Skip to Step 2 (first-run create happens in Step 4).
2. Read the Raycast note by `noteId`.
3. Parse the H1 date from the body (`# YYYY-MM-DD`). If there is no H1 date, treat the body as undated capture and use **yesterday** (prior calendar day in Australia/Brisbane) as the snapshot date — better to archive than to destroy.
4. Inbox path: `/Users/tim/Documents/Obsidian/inbox/daily-note-YYYY-MM-DD.md` using the **H1 date**, not today.
5. If that inbox file already exists with `status: processed`, do not overwrite it.
6. If the H1 date **is today**, skip the snapshot (already on today's card). Continue to Step 2.
7. Otherwise write (or overwrite only if existing file is `status: pending` / missing status):

```markdown
---
source: raycast-notes
noteId: <id>
title: Daily note
date: YYYY-MM-DD
createdAt: <from Raycast>
updatedAt: <from Raycast>
syncedAt: <now ISO>
status: pending
---

<Raycast body, strip HTML &nbsp; spacers, keep checkboxes and Capture>
```

8. Confirm the file exists on disk before continuing. If the write failed, **stop**. Do not replace Raycast.

---

## Step 2 — Vault daily-briefing

Read and follow `/Users/tim/Documents/Obsidian/.claude/skills/daily-briefing/SKILL.md` in full.

That skill already:

- Wraps the prior day if it has no `### Summary` (via daily-wrap)
- Archives prior-month dailies
- Check-in conversation
- Writes `notes/daily-note/YYYY-MM-DD.md`
- Updates `.briefing-state.md`

When wrap runs (Step 0 of daily-briefing), it must consume `inbox/daily-note-<prior-date>.md` if present — that is patched into daily-wrap. Do not duplicate wrap logic here.

Keep the check-in. Do not skip it to “just sync notes”.

---

## Step 3 — Derive slim card → outbox

After today's vault daily exists, write `/Users/tim/Documents/Obsidian/outbox/daily-note.md`.

Source: `notes/daily-note/YYYY-MM-DD.md` (today).

Include:

- H1 `# YYYY-MM-DD`
- **Focus:** one or two sentences from `### Focus`
- `## Today` — open `- [ ]` items whose project is marked *today* / current lane. Drop `(stale)`, `*not today*`, parked projects, Learning, Briefing prose, wikilinks (plain project names only)
- `## Capture` — empty stub (or keep Capture from the Raycast snapshot if H1 was already today and Capture had content)

Frontmatter:

```yaml
---
action: replace   # create on first run when state.noteId is empty
noteId: <from state, omit if empty>
title: Daily note
status: pending
source: daily-note
date: YYYY-MM-DD
---
```

Do not put Learning, parked projects, or `[[wikilinks]]` in the slim card.

---

## Step 4 — Replace (or create) the Raycast Daily note

1. Read `outbox/daily-note.md`. If `status` is not `pending`, stop.
2. Body to send = outbox file minus frontmatter.
3. If `state.noteId` is empty:
   - `create-note` with title `Daily note` and the slim body
   - Save returned `noteId` to `state.md` and to outbox frontmatter
4. If `noteId` is set:
   - Read current Raycast body
   - `replace-text` the **entire current body** with the slim body
   - If replace fails because the old string does not match, stop and show both bodies — do not create a second note
5. Pin reminder: tell the user to pin it (`⇧⌘P`) if this was a create, so it is `⌘0`.
6. Set outbox `status: sent` and `sentAt`. Do not delete the outbox file.

---

## Slim-card template

```markdown
# YYYY-MM-DD

**Focus:** …

## Today

- [ ] …

## Capture

```

---

## Failure modes

| Situation | Action |
|---|---|
| Raycast read fails | Stop. No vault wrap that depends on inbox, no replace |
| Inbox write fails | Stop |
| Vault daily already has real content | daily-briefing prepends briefing (its own rule) |
| Outbox pending but replace fails | Leave outbox `pending`; Raycast unchanged; inbox already safe |
| User re-runs after a successful morning | H1 is today → no inbox overwrite; rewrite outbox; replace Raycast with the same/updated slim card |
| `noteId` in state 404s | Search by title; if still missing, treat as first run but **do not** snapshot-skip if an undated Daily note exists under another title |

## Out of scope

- Syncing other Raycast notes to inbox
- Writing back into `TODO - MAIN`
- EOD `/daily-wrap` from Raycast (morning Step 1 already recovers a forgotten wrap)
- Bidirectional project scratch pads
