---
name: handover
description: >
  Generate a handover note for a fellow developer and start a fresh session with it pre-loaded.
  Use this skill when the user runs /handover, asks to "hand off", "write a handover note",
  "pass context to a new session", or "start a fresh thread with context". Gathers git state,
  in-progress beads issues, and current work context, writes a 1-paragraph briefing into project
  memory, then automatically clears the context so the new session opens with the handover
  already presented. The receiving session is self-cleaning — the note is deleted after it surfaces.
---

# Handover

Generate a concise developer handover note and inject it into a fresh session automatically.

## When to use

Triggered by `/handover` or natural language like "write a handover", "hand off to new session", "start fresh with context".

---

## Step 1 — Gather context

Run these in parallel:

```bash
git status --short
git log --oneline -8
git branch --show-current
```

Also check if beads is active:
```bash
bd list 2>/dev/null || echo "NO_BEADS"
```

If beads is active (no error), get in-progress issues:
```bash
bd list --status in_progress 2>/dev/null || bd list 2>/dev/null | head -20
```

Read `CLAUDE.md` if present in the working directory — it often has project context.

---

## Step 2 — Generate the handover paragraph

Write a single tight paragraph (4–6 sentences) covering:

1. **What we're working on** — the feature, bug, or task and its purpose
2. **Current state** — what's done, what's in progress, any blockers or decisions pending
3. **Where to look** — key files, branches, PRs, or relevant docs (be specific — name files/paths)
4. **Where to start** — the most logical next action for the receiving dev
5. **Beads IDs** — if beads is active, mention the relevant issue IDs (e.g. `BD-12`, `BD-15`)

Keep it dense and practical. No bullet points — prose only. Write it as if you're leaving a note on a colleague's desk before heading out.

---

## Step 3 — Write to project memory

Derive the project memory path from the current working directory:
```bash
project_key="-$(pwd | sed 's|^/||; s|/|-|g')"
memory_dir="$HOME/.claude/projects/${project_key}/memory"
mkdir -p "$memory_dir"
```

Write the handover to `$memory_dir/handover_pending.md` with this exact format:

```markdown
---
name: Pending Handover
description: IMPORTANT - A handover note is waiting. Present it at the start of this session then self-clean.
type: project
---

**HANDOVER INSTRUCTIONS FOR THIS SESSION:**
You are starting a fresh session with a handover note from the previous developer session.

As your very first response (before anything else), present the handover note below clearly, formatted as:

---
**Handover from previous session:**

[paste the paragraph here]

---

Then immediately self-clean:
1. Delete this file: `[memory_dir]/handover_pending.md`
2. Remove its line from `[memory_dir]/MEMORY.md`

After self-cleaning, ask: "Where would you like to start?"
```

(Replace `[memory_dir]` with the actual path.)

Then add a line to `$memory_dir/MEMORY.md` (create it if it doesn't exist):
```
- [Pending Handover](handover_pending.md) — IMPORTANT: present this note at session start then delete
```

Add it as the **first line** of MEMORY.md so it's seen immediately.

---

## Step 4 — Trigger the clear

Tell the user: "Handover prepared. Clearing context in 3 seconds…"

Then run this script in the background (do not await it):
```bash
scripts/fire_clear.sh &
```

The script sends `/clear` to the current tmux pane after a short delay, giving Claude time to finish responding.

---

## Step 5 — What happens in the fresh session

The new session loads memory, sees `handover_pending.md`, and:
1. Presents the handover note as its first response
2. Deletes `handover_pending.md`
3. Removes the entry from `MEMORY.md`
4. Asks where to start

The receiving dev sees a clean thread starting with full context. No trace of the handover machinery remains.
