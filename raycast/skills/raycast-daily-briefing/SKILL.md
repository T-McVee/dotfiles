---
name: raycast-daily-briefing
description: Morning briefing from Raycast. Export every Raycast note touched since the last sync into the Obsidian inbox, run the vault daily-briefing (which processes that inbox and may wrap yesterday), then replace the pinned Raycast Daily note with the day card the vault produced. Use when the user says "/daily-briefing", "daily briefing", "brief me", "start my day", or wants the Raycast Daily note refreshed from the second brain. Requires Raycast Notes tools.
---

# Raycast Daily Briefing

Orchestrates the morning loop between Raycast Notes and the Obsidian second brain.

The split matters: **this skill owns Raycast I/O and nothing else.** It is deliberately dumb. It copies whole notes out of Raycast into `inbox/` and copies one day card back in. It does not decide what any of that content means, because the Raycast Notes API can only ever hand back a full note, never a diff. Working out what is actually new is the vault's job, and the vault has the project files and git history needed to do it. Resist the urge to be clever here.

The pinned Raycast note named **Daily note** is overwritten in place each morning. Dated history lives in the vault.

## Paths

- **Second brain root:** `/Users/tim/Documents/Obsidian`
- **Vault:** `/Users/tim/Documents/Obsidian/notes`
- **Inbox (into the vault):** `/Users/tim/Documents/Obsidian/inbox`
- **Outbox (out of the vault):** `/Users/tim/Documents/Obsidian/outbox`
- **Vault daily notes:** `notes/daily-note/YYYY-MM-DD.md` (current month); archives in `notes/daily-note/YYYY-MM/`
- **Vault briefing skill:** `/Users/tim/Documents/Obsidian/.claude/skills/daily-briefing/SKILL.md`
- **Vault wrap skill:** `/Users/tim/Documents/Obsidian/.claude/skills/daily-wrap/SKILL.md`
- **State file:** `/Users/tim/dotfiles/raycast/skills/raycast-daily-briefing/state.md`

Today's date comes from system context (`currentDate`). Never infer the weekday from the date, run `date +%A` if needed.

## Hard rules

1. Export **before** briefing or Raycast replace. That is what makes a missed EOD wrap recoverable: the content is already safe on disk before anything overwrites it.
2. Export is a full copy every time. Never try to diff, merge, or trim a note on the way out.
3. Never write into the inbox for a note you did not just read successfully from Raycast.
4. Vault Briefing and Learning prose never round-trip through Raycast. Only the day card goes back.
5. Raycast replace is **last**, and only after the export succeeded.
6. Only advance `lastSyncAt` once the export files are confirmed on disk. An over-eager timestamp silently loses a day of captures, which is the worst failure this loop has.
7. If Raycast Notes tools are unavailable, stop. Do not invent a Daily note body.

## State file

Create `state.md` if missing:

```markdown
## Raycast Daily note
noteId:
title: Daily note
createdAt:

## Sync
lastSyncAt:
```

After the first successful `create-note`, persist `noteId`. Every later send is a replace of that id. Never create a second Daily note if `noteId` is set.

`lastSyncAt` is the high-water mark for exports. It is not "yesterday": using a stored timestamp means a weekend, a sick day, or a skipped morning cannot swallow captures. Anything edited while you were not running still gets picked up on the next run.

---

## Step 1: Export changed notes to the inbox

1. Read `state.md`.
2. List Raycast notes and select every note whose `updatedAt` is later than `lastSyncAt`.
   - If `lastSyncAt` is empty (first run), fall back to notes updated in the last 24 hours. Do not export the entire Raycast library on a first run; the vault has no snapshots yet and would have to reason about everything at once.
3. For each selected note, read it and write `inbox/<slug>.md`.

   **If the note's id matches `state.noteId`, the slug is always `daily-note`, whatever the note is titled.** That note is the pinned card this loop overwrites every morning, and Raycast titles a note from its first line, which is the card's `# YYYY-MM-DD` heading. So its title changes daily. Keying its slug off the id instead of the title is the only way it stays stable.

   For every other note the slug is the title in kebab-case (`TODO - MAIN` becomes `todo-main.md`, `DevCop '26` becomes `devcop-26.md`).

   Slug stability is the load-bearing property here. The vault diffs each inbox file against `notes/.raycast-snapshots/<slug>.md` to find what changed, so a slug that drifts reads as a brand new note, loses the diff, and re-imports content that was already filed. Duplicated todos in a project file are tedious to unpick by hand.

```markdown
---
source: raycast-notes
noteId: <id>
title: <Raycast title>
kind: daily | project | standing-list | unknown
createdAt: <from Raycast>
updatedAt: <from Raycast>
syncedAt: <now ISO>
status: pending
---

<Raycast body verbatim, strip HTML &nbsp; spacers, keep checkboxes and Capture>
```

`kind` is a routing hint for the vault, guessed from the title:

| Note | `kind` |
|---|---|
| Id matches `state.noteId` (the pinned card) | `daily` |
| Titled `Daily note`, `Today`, or a bare `YYYY-MM-DD` | `daily` |
| Matches a file in `notes/projects/` | `project` |
| `TODO - MAIN` or another long-lived list | `standing-list` |
| Anything else | `unknown` |

Guess cheaply and move on. The vault reads the content and overrides you when you are wrong, so a bad guess costs nothing and a slow export costs the user their morning.

4. Confirm every file exists on disk. If any write failed, **stop**. Do not advance `lastSyncAt`, do not replace Raycast.
5. Set `lastSyncAt` to the current time.

---

## Step 2: Run the vault daily-briefing

Read and follow `/Users/tim/Documents/Obsidian/.claude/skills/daily-briefing/SKILL.md` in full.

That skill owns everything from here until the outbox exists. It processes the inbox and clears it (its Step 0), wraps the prior day if it has no `### Summary`, archives prior-month dailies, runs the check-in, writes today's daily note, and writes the day card to `outbox/daily-note.md`.

Do not duplicate any of that logic here, and do not process the inbox yourself. Keep the check-in, and do not skip it to "just sync notes": the check-in is the part that makes the briefing worth reading.

---

## Step 3: Replace (or create) the Raycast Daily note

1. Read `outbox/daily-note.md`. If it does not exist, the vault briefing did not finish. Stop.
2. If `status` is not `pending`, the card has already been sent. Stop.
3. Body to send is the outbox file minus its frontmatter.
4. If `state.noteId` is empty, **search Raycast by title before creating anything**, trying `Daily note`, `Today`, and any bare `YYYY-MM-DD` title (a card created by an earlier run will have been renamed to its own H1 date).
   - Found: adopt that id, save it to `state.md`, and treat this as a replace (step 5).
   - Genuinely absent: `create-note` with title `Daily note` and the card body, save the returned `noteId` to `state.md`, and tell the user to pin it (`⇧⌘P`) so it lands on `⌘0`.

   An empty `noteId` means "this loop has not run before", which is not the same as "no Daily note exists". The user has been keeping that note by hand. Creating a second one splits their captures across two notes, and because the export in Step 1 reads by id, the half they keep typing into would stop reaching the vault entirely. Always look before you create.
5. If `noteId` is set:
   - Read the current Raycast body
   - `replace-text` the **entire** current body with the card body
   - If the replace fails because the old string does not match, stop and show both bodies. Do not create a second note; a duplicate Daily note splits the user's captures in two and is painful to unpick.
6. Set outbox `status: sent` and `sentAt`. Leave the file in place.

Anything the user typed under `## Capture` before this step ran was already exported in Step 1, so overwriting the note here is safe. That ordering is the only thing making it safe, which is why Step 1 comes first.

---

## Failure modes

| Situation | Action |
|---|---|
| Raycast read fails | Stop. Nothing exported, nothing replaced, `lastSyncAt` unchanged |
| Any inbox write fails | Stop. Leave `lastSyncAt` unchanged so the next run re-exports |
| Vault daily already has real content | daily-briefing prepends the briefing (its own rule) |
| Outbox missing after Step 2 | Vault briefing did not complete. Stop, leave Raycast alone |
| Outbox `pending` but replace fails | Leave `pending`; Raycast unchanged; inbox already safe |
| Re-run the same morning | Nothing new since `lastSyncAt`, so no export. Inbox is empty, vault rewrites the card, replace sends the same or updated card |
| `noteId` 404s | Search by title, including a bare `YYYY-MM-DD` title, since Raycast renames the card from its H1 each time it is replaced. If still missing, treat as a create, but never create a second note while a card exists under any title |
| Inbox not empty at Step 3 | The vault could not process something. Report it, do not clear it yourself |

## Out of scope

- Deciding what inbox content means, or where it belongs in the vault
- Writing back into any Raycast note other than the pinned Daily note
- EOD `/daily-wrap` from Raycast (the morning export recovers a forgotten wrap)
- Bidirectional project scratch pads. Project notes flow Raycast to vault only
