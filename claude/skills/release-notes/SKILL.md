---
name: release-notes
description: Generate release notes from git branch history. Use this skill whenever the user asks to create, prep, draft, or generate release notes, or asks "what changed on this branch", "summarize this branch's work", or wants a changelog for QA/PM review. Trigger even if they say things like "write up what we did" or "summarize the branch for the PR".
---

# Release Notes Generator

Generate concise, QA/PM-friendly release notes from the current git branch's commit history.

## How it works

The release notes capture all work done on the current feature or bug branch since it diverged from `main`. The audience is QA teams and PMs — they care about *what changed* from a user/system perspective, not implementation specifics.

## Steps

### 1. Gather the commit history

Run:
```bash
git log main..HEAD --oneline --no-merges
```

If the branch has no commits ahead of `main`, let the user know there's nothing to generate notes from.

Also read the actual diffs to understand what changed — commit messages alone can be vague or misleading:
```bash
git diff main...HEAD --stat
```

For commits where the message is unclear, read the actual diff to understand the change:
```bash
git show <sha> --stat
```

### 2. Understand the work, not the code

For each commit (or logical group of commits), identify what was accomplished from a user or system perspective. Focus on:
- What feature or behavior was added or changed
- What was fixed
- What was connected or integrated

Avoid mentioning:
- Function, class, method, or variable names
- File paths or internal module names
- Technical implementation patterns (unless they *are* the point, like "migrated from REST to GraphQL")

Good: "Added validation to the signup form for email and password fields"
Bad: "Added validateInput() to SignupForm.tsx with regex checks"

Good: "Wired up the dashboard charts to pull from the analytics API"
Bad: "Connected DashboardChart component to AnalyticsService via useQuery hook"

### 3. Order the notes

Default to chronological order (the order work was completed). However, if related work is spread across non-adjacent commits, group it together. For example, if API work was done early, then other tasks, then more API work — group all the API notes together. Use your judgment; only reorder when it genuinely helps readability.

### 4. Write the file

Generate a timestamp and write the file:

```bash
date +%Y%m%d-%H%M%S
```

Create `release-notes-{timestamp}.md` in the working directory with this structure:

```markdown
# Release Notes — {branch-name}

- First thing that was done
- Second thing that was done
- Another change
- ...
```

Keep bullets brief — one line each when possible. No categories, no headers beyond the title. If a bullet needs a small clarification, a short parenthetical is fine.

### 5. Present to the user

After writing the file, show the contents and the file path. Ask if they'd like any adjustments before using it.
