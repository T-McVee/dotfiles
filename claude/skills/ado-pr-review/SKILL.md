---
name: ado-pr-review
description: Open a draft Azure DevOps PR, then run an independent AI review that posts inline comments on it, then monitor the PR on a timer and automatically address the review comments. Use when the user wants to "ship for review and auto-address feedback", "open a PR and self-review it", "review my own PR and fix the comments", "post a PR and watch it", or asks for a review-and-fix loop on an ADO pull request. Builds on the ado-pr skill.
---

# ADO PR Review Loop

Creates a draft PR in Azure DevOps, has an **independent reviewer** post inline
comments on it, then **monitors the PR on a 5-minute loop** and addresses each
review comment automatically — committing fixes, replying on the thread, and
resolving it.

The three stages are deliberately separated so the review is not biased by the
implementing session's context:

1. **Create** the draft PR  → reuse the `ado-pr` skill.
2. **Review**  → a fresh-context subagent reviews the diff and posts inline
   comments, each tagged with a hidden marker so the loop can recognise them.
3. **Monitor & fix** → a `/loop` polls the PR every 5 min, reads the unresolved
   marked threads, fixes each one, pushes, replies, and resolves the thread.

All ADO comment I/O goes through the helper script:
`~/.claude/skills/ado-pr-review/scripts/ado-pr.sh` (org/project/repo are derived
from the `origin` remote; auth uses the active `az login`). Run `ado-pr.sh env`
to sanity-check the derived connection.

---

## Stage 1 — Create the draft PR

Invoke the **`ado-pr`** skill to run QA checks, build the body, and create the
draft PR. Do not reimplement it.

After it completes, capture the **PR id**. The skill prints the PR URL ending in
the id; if unsure, resolve it from the current branch:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
PR_ID=$(az repos pr list --org https://dev.azure.com/Mojo-Soup \
  --project "Metro South HHS" --repository metro-south-timesheets \
  --source-branch "$BRANCH" --status active \
  --query "[0].pullRequestId" -o tsv)
```

Confirm with `scripts/ado-pr.sh show "$PR_ID"`. Keep `$PR_ID` for all later
stages.

---

## Stage 2 — Independent review

Pick a reviewer. Both produce inline comments carrying the `[claude-ai-review]`
marker, so Stage 3 works identically regardless of which you use. If the user
hasn't said which, ask — or honour any standing preference.

- **Option A — in-session Claude subagent** (default; no extra tooling). See
  "Reviewer A" below.
- **Option B — Cursor CLI / GPT-5.5** (a genuinely separate process and a
  *different model* → maximally independent review; surfaces issues a Claude
  reviewer may share blind spots on). See "Reviewer B" below. Requires the
  Cursor CLI (`agent`) installed and logged in.

### Reviewer A — in-session Claude subagent

Launch a review **subagent** (Agent tool, `subagent_type: code-reviewer` if
available, otherwise `general-purpose`). Give it a clean, self-contained brief —
it must not assume any of this session's context. The brief must include:

- The PR id, repo path, and base branch (`main`).
- The exact diff to review: `git diff main...HEAD` and `git diff main...HEAD --stat`.
- The path to the helper script and how to post comments (below).
- Reviewer guidance (mirror the `code-review` skill's bar):
  - Only flag **real, high-confidence problems**: correctness bugs, security
    issues, broken logic, violations of guidance in nearby `CLAUDE.md` files.
  - **Do not** flag pre-existing issues, pedantic style, formatting, missing
    tests/docs, or anything a linter/typechecker/compiler would catch.
  - For each issue: locate the precise `file:line` in the diff and post one
    inline comment. Keep comments specific and actionable. No emojis.
  - If there are no real issues, post nothing.

How the subagent posts each comment (it writes the body to a temp file, then):

```bash
SCRIPT=~/.claude/skills/ado-pr-review/scripts/ado-pr.sh
# inline comment on a specific line:
"$SCRIPT" comment "$PR_ID" "src/utils/foo.ts" 42 /tmp/comment.md
# optional overview/summary thread (not tied to a line):
"$SCRIPT" comment-general "$PR_ID" /tmp/summary.md
```

The helper prepends the `[claude-ai-review]` marker automatically — the subagent
must NOT add it. The marker is how Stage 3 distinguishes AI-review threads from
human reviewers' threads (comments post under the user's ADO identity, so author
cannot be used to tell them apart).

When the subagent returns, report how many comments it posted.

### Reviewer B — Cursor CLI / GPT-5.5

One command runs the review and posts the comments:

```bash
~/.claude/skills/ado-pr-review/scripts/cursor-review.sh "$PR_ID"        # gpt-5.5-high
~/.claude/skills/ado-pr-review/scripts/cursor-review.sh "$PR_ID" gpt-5.4-high   # other model
DRY_RUN=1 ~/.claude/skills/ado-pr-review/scripts/cursor-review.sh "$PR_ID"      # print, don't post
```

What it does: runs `agent -p --model <model> --mode ask --trust` (read-only — the
reviewer can read files but cannot write or run shell), embeds the `main...HEAD`
diff in the prompt with the same review bar as Reviewer A, requires a strict JSON
findings array back, then posts each finding inline via `ado-pr.sh comment` (so
the marker/formatting stay centralised). It prints the finding count; report it
to the user. Default model is `gpt-5.5-high` (run `agent --list-models` for
others). Preview with `DRY_RUN=1` before posting if the user wants to vet
findings first.

---

## Stage 3 — Monitor & fix loop

Start a poll with the **`/loop`** skill at a 5-minute cadence, running the
**Each tick** procedure below:

```
/loop 5m Address new Claude review comments on ADO PR $PR_ID per the
ado-pr-review skill's "Each tick" procedure.
```

Tell the user the loop is running, how to stop it, and that it will end itself
once there are no unresolved AI-review threads left.

### Each tick

Run with `PR_ID` and `SCRIPT=~/.claude/skills/ado-pr-review/scripts/ado-pr.sh`:

1. **Sync the branch** so fixes apply cleanly:
   ```bash
   git pull --rebase
   ```

2. **List unresolved AI-review threads** (marked + still active):
   ```bash
   "$SCRIPT" list-claude-threads "$PR_ID"
   ```
   Each line is JSON: `{id,status,filePath,line,author,isClaudeReview,commentCount,firstComment}`.

3. **If the list is empty → the loop is done.** Report "No open AI-review
   threads — review loop complete" and **end the loop** (do not reschedule /
   omit the wakeup). Stop here.

4. **Skip threads already handled this run**: ignore any thread with
   `commentCount > 1` (it already has a reply). Only act on `commentCount == 1`.

5. **For each remaining thread**, in order:
   a. Read the issue from `firstComment` (and open the full file at
      `filePath:line` for context).
   b. **Fix it** if it is a genuine, actionable problem. Make the minimal
      correct change. Match surrounding code style.
   c. **Verify** the change — run the narrowest relevant check from
      `.claude/pr-check.yaml` (e.g. typecheck + the affected test file). Don't
      run the full suite every tick.
   d. **Commit** with a conventional message referencing the fix, then **push**:
      ```bash
      git add -A && git commit -m "fix: <what you changed> (PR review)"
      git push
      ```
   e. **Reply and resolve** the thread:
      ```bash
      printf 'Addressed in %s — <one-line summary of the fix>.' "$(git rev-parse --short HEAD)" > /tmp/reply.md
      "$SCRIPT" reply   "$PR_ID" <threadId> /tmp/reply.md
      "$SCRIPT" resolve "$PR_ID" <threadId> fixed
      ```

6. **If a comment is not actionable or you are not confident** in a fix:
   reply explaining why and resolve as `wontFix` so it does not recur, then
   surface it to the user in your tick summary. Never leave it unresolved — an
   unresolved thread will be re-processed next tick and can loop forever.

7. After processing all threads, print a one-line summary of the tick (threads
   fixed / deferred / commits pushed) so the user can follow along.

---

## Reference — helper script

`scripts/ado-pr.sh <subcommand>`:

| Subcommand | Purpose |
|---|---|
| `env` | Print derived org/project/repo/base (debug). |
| `show <prId>` | PR title/status/url sanity check. |
| `list-threads <prId>` | All active threads (any author). |
| `list-claude-threads <prId>` | Active threads carrying the `[claude-ai-review]` marker — the loop's input. |
| `comment <prId> <file> <line> <bodyFile>` | New inline review thread (marker auto-prepended). |
| `comment-general <prId> <bodyFile>` | New overview thread (marker auto-prepended). |
| `reply <prId> <threadId> <bodyFile>` | Append a reply to a thread. |
| `resolve <prId> <threadId> [fixed\|closed\|wontFix\|active]` | Set thread status (default `fixed`). |

`scripts/cursor-review.sh <prId> [model]` — run Stage 2 (Reviewer B) via the
Cursor CLI / GPT-5.5 and post findings. `DRY_RUN=1` to preview without posting.

## Notes & safety

- **Scope is AI-review comments only.** The loop acts solely on threads carrying
  the `[claude-ai-review]` marker. Human reviewers' threads are never auto-fixed
  — surface those to the user instead.
- **Prerequisites:** `az login` active; `azure-devops` extension installed; `jq`
  on PATH. The repo's `origin` must be the ADO remote. For Reviewer B only: the
  Cursor CLI (`agent`) installed and logged in.
- **Pushing:** the loop pushes fix commits to the PR branch. If the branch has no
  upstream, set it once (`git push -u origin "$BRANCH"`) before starting.
- **Termination:** the loop self-terminates when no marked unresolved threads
  remain (step 3). The user can also stop `/loop` at any time.
- **Idempotency:** resolving a thread removes it from the next tick's list; the
  `commentCount > 1` guard prevents double-processing within a tick window.
