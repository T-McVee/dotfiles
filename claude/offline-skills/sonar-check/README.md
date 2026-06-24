# sonar-check Skill — Setup & Usage

A read-only "ping" for SonarQube Cloud — ask Claude what your current branch's code quality looks like without leaving the chat.

For the procedural skill instructions Claude follows internally, see `SKILL.md`. This README is for **you, the developer using the skill.**

---

## What it actually does

`/sonar-check` queries the SonarQube Cloud API and reports the **latest analysis already stored on the server** for your current branch (or open PR). In plain English:

1. Detects your current git branch
2. Resolves the project key (from `sonar-project.properties`, the pipeline YAML, or the repo name convention)
3. Checks if you have an open ADO PR for the branch — if yes, queries the PR-mode analysis; if no, the branch analysis
4. Hits SonarCloud's HTTP API to fetch:
   - Quality Gate status (✅ OK / ❌ ERROR)
   - Key metrics (bugs, vulnerabilities, code smells, coverage, duplications)
   - Top open issues with file:line references
5. Formats it all into a tidy report in chat with links back to SonarCloud

**It does NOT trigger a new scan.** It only reads what's already there. Scans happen automatically when:
- Code is pushed to `main` (main pipeline runs → main scan updates)
- A PR is opened or updated (PR pipeline runs → PR scan updates)
- You manually re-run the pipeline in ADO (Pipelines → ⋮ → Run new)

---

## When to use it

| Situation | What to ask | What you get |
|-----------|-------------|--------------|
| Mid-coding, want a quick health check | `/sonar-check` | Current state of `main` if you're on `main`, or the open PR if you're on a feature branch with a PR raised |
| About to raise a PR | `/sonar-check` | Confirms quality gate result on current state of main as a baseline |
| PR is open, scan just finished, want to see what's flagged in chat | `/sonar-check` | The PR-mode scan with all PR diff issues |
| Quality gate failed and you want to understand why | `/sonar-check` | The failing conditions section spells out which thresholds were missed |
| Wondering if a fix landed | `/sonar-check` after re-running the pipeline | Shows updated counts |

---

## When NOT to use it (use something else instead)

`/sonar-check` is the wrong tool for these:

| Want this? | Use this instead |
|-----------|------------------|
| "Show me issues in the file I'm editing right now, as I type" | **SonarQube for IDE** (Cursor extension) — gives real-time inline squiggles |
| "Scan my uncommitted changes against main" | **SonarQube for IDE** (continuously analyses files you have open). Or push + raise the PR — the PR pipeline scans the diff |
| "Run a fresh scan from my laptop" | Don't — push to your branch and raise the PR, the pipeline will scan |
| "Add SonarQube to a new repo" | `/sonar-integrate` — sets up everything |
| "Bypass the quality gate" | Talk to whoever set the gate. `/sonar-check` is read-only |

---

## How to use it

### One-time setup (per developer)

You only need to do this once per machine, ever:

1. **Generate a personal SonarCloud token:**
   - Open https://sonarcloud.io/account/security
   - Sign in with your Mojo Soup account
   - Generate a token named something like `claude-sonar-check`, expires in 1 year, type "User Token"
   - **Copy it now** — SonarCloud only shows it once

2. **Set it as `SONAR_TOKEN` env var:**

   **Windows (PowerShell):**
   ```powershell
   [System.Environment]::SetEnvironmentVariable('SONAR_TOKEN', 'PASTE-YOUR-TOKEN-HERE', 'User')
   ```
   Then **fully quit Cursor** (tray icon → Exit) and reopen. Closing the window isn't enough — child processes inherit env vars at editor launch.

   **macOS:**
   ```bash
   echo 'export SONAR_TOKEN="PASTE-YOUR-TOKEN-HERE"' >> ~/.zshrc
   ```
   Then **fully quit Cursor** (`Cmd+Q`, not just close window) and reopen.

3. **Verify:**
   Open a fresh terminal in Cursor and run:
   ```bash
   echo $SONAR_TOKEN     # macOS / Linux
   $env:SONAR_TOKEN      # Windows PowerShell
   ```
   Should print your token. If empty, you didn't fully quit the editor — try again.

### Day-to-day usage

Once `SONAR_TOKEN` is set, just type `/sonar-check` in Claude Code. That's it. No flags, no arguments.

It auto-detects:
- Your current branch
- Whether there's an open PR for that branch
- The SonarCloud project key from `sonar-project.properties` or the pipeline YAML

Other natural-language phrases that trigger the same skill:
- "check sonar"
- "what does sonarqube say"
- "did the quality gate pass"
- "any sonar issues on my branch"
- "sonarcloud status"

---

## Reading the output

A typical report has four sections:

### 1. Quality Gate

```
Quality Gate: ❌ ERROR
Branch: main (latest scan: 2026-03-06 15:50 AEST)
```

The big pass/fail verdict. `✅ OK` means the gate passed. `❌ ERROR` means at least one condition was breached. `⚠️ WARN` is for legacy gates that have warning thresholds (rare now).

If the gate fails, you'll see the failing conditions broken out:

```
Failing conditions:
❌ New coverage:                 0.0%   (threshold: ≥ 80%)
❌ New security hotspots reviewed: 0.0% (threshold: ≥ 100%)
```

Each row tells you the actual measured value vs. the threshold defined in your Quality Gate.

### 2. Metrics

Overall + new-code numbers for the big six:
- **Bugs** — definite logical errors
- **Vulnerabilities** — code that's a security risk
- **Code smells** — maintainability issues (refactor targets)
- **Coverage** — percentage of code exercised by tests
- **Duplications** — percentage of duplicated lines
- **Security hotspots** — code that's *not necessarily* a vulnerability but needs human review (e.g. uses of crypto, eval, regex with user input)

"Overall" is the whole codebase. "New code" is whatever your project's New Code definition covers (typically last 30 days or since the last version tag) — this is what the Quality Gate actually evaluates.

### 3. Top open issues

A handful of the highest-severity unresolved issues, each with:
- Severity icon: 🔴 BLOCKER, 🟠 CRITICAL, 🟡 MAJOR, 🔵 MINOR, ⚪ INFO
- File path and line number — click-through in Cursor with `Ctrl+Click`
- One-line description of the problem

### 4. Links

Direct deep-links into the SonarCloud UI for the project overview and full issue list.

---

## Troubleshooting

### "No SONAR_TOKEN set"

Your env var isn't visible to Cursor's process. The fix is **always**: close all terminal windows, fully quit Cursor (tray Exit on Windows / Cmd+Q on macOS), reopen Cursor, then re-run `/sonar-check`.

If it's still empty after a full restart, you set the env var in the wrong scope. On Windows, double-check you used the `User` scope (third argument to `SetEnvironmentVariable`), not `Process` (which only persists for that one PowerShell session). On macOS, double-check the line is in `~/.zshrc` (not `~/.zshrc-old` or similar).

### "Branch X has no SonarQube analysis yet"

You're on a branch that's never been scanned. Two scenarios:

1. **Local-only branch** (never pushed) — SonarCloud has no idea this branch exists. For mid-coding feedback, use SonarQube for IDE in your editor (real-time inline). To get a SonarCloud scan, push the branch + raise a PR.

2. **Pushed branch with no PR** — the branch was pushed but no PR exists, so no PR-mode scan has run. SonarCloud only auto-scans branches that are `main` or have an open PR. Raise the PR to trigger a scan.

The skill will fall back to showing `main` branch results so you have *some* signal — but those are the project baseline, not your branch's.

### "Quality gate is failing but I just fixed it"

Gate evaluation is **baked into each scan at scan time**. Changing your quality gate definition / assignment on SonarCloud doesn't retro-evaluate old scan results. To see new gate config take effect:

- ADO → Pipelines → find the main pipeline → latest run → ⋮ menu → **Run new**
- Wait ~5 minutes for the scan to finish
- Re-run `/sonar-check` — new result will reflect the new gate

You don't need to push a commit. Just re-run the pipeline.

### "Returns 401 / Unauthorized"

Your token is invalid, revoked, or expired. Generate a new one at sonarcloud.io/account/security and update your `SONAR_TOKEN` env var. Don't forget the full editor quit + relaunch after updating.

### "Returns 404 / project not found"

Either:
- The project key doesn't exist on SonarCloud yet (no scan has ever run for this repo)
- The project key the skill derived doesn't match what's on SonarCloud — most common cause is a hand-crafted `sonar-project.properties` with a different key from what the skill expects

Check the `sonar.projectKey` in the repo's `sonar-project.properties` (or `projectKey:` in the pipeline's `SonarCloudPrepare` task) and compare to what SonarCloud shows under Projects.

### "I see different issues than my colleague does"

Two possibilities:

1. **One of you isn't in connected mode** — SonarQube for IDE without connected mode uses default Sonar Way rules, not your Mojo Soup quality profile. Status bar in Cursor should say "Connected to SonarCloud, project: Mojo-Soup_<repo>". If not, run `SonarQube for IDE: Connect to SonarQube Cloud` in the Command Palette.

2. **One of you is using `/sonar-check`, the other is looking at SonarQube for IDE** — they show different things:
   - `/sonar-check` = whole-project server-side scan results from CI
   - SonarQube for IDE = real-time analysis of files you have open in your editor

---

## Why SonarQube for IDE doesn't show every issue SonarCloud has

If you've ever opened a Mojo Soup repo in Cursor and thought "wait — SonarCloud says we have 187 code smells but my Problems panel is empty," **that's expected behaviour**. SonarQube for IDE is file-scoped, not project-scoped.

### What gets analysed locally

| What | When |
|------|------|
| The file you have open and active | Continuously as you type (on-the-fly) |
| Files you've opened this session | When you switched to them |
| Files you've edited but switched away from | Stays analysed until you close the editor |
| Files you've **never opened** | **Never analysed locally** |

So if a colleague triaged an issue in `Sidebar.tsx` 6 months ago and you've never opened that file in Cursor, you won't see anything from it in your Problems panel — even though SonarCloud knows all about it from CI scans.

### Why it works this way (it's a feature, not a bug)

Three deliberate reasons:

1. **Performance.** Full-project analysis takes 2-5 minutes. Doing that on every editor launch would render Cursor unusable. File-scoped analysis is sub-second.
2. **Relevance.** When editing `UserFormDialog.tsx`, you care about issues in `UserFormDialog.tsx` — not a reminder that `setupMsal.ts` has commented-out code from 2 years ago. The CI scan + SonarCloud UI is where you look for the holistic view.
3. **Architecture.** SonarQube for IDE re-runs rules locally — it doesn't pull pre-computed issues from the server. So unanalysed = unseen, regardless of what's on the server.

### Three views, three purposes

```
┌─────────────────────────────────────────────────────────────────┐
│  Files I'm actively editing in Cursor                           │
│  → SonarQube for IDE Problems panel (Ctrl+Shift+M)              │
│  → Real-time, only the files you've opened                      │
│  → Use when: writing/refactoring code                           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Whole project, latest CI scan, formatted for chat              │
│  → /sonar-check                                                 │
│  → Reads SonarCloud's authoritative scan, summarises top issues │
│  → Use when: pre-PR sanity check, or "is gate green?"           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Whole project, full UI with filtering, sorting, drill-down     │
│  → SonarCloud UI in browser                                     │
│  → Every issue, every metric, every historical scan             │
│  → Use when: planning a tech debt sprint, security review,      │
│    or just want the rich UI                                     │
└─────────────────────────────────────────────────────────────────┘
```

### If you actually want to see more locally

You can manually broaden the scope of analysis:

- **Single folder:** Right-click a folder in the Explorer panel → look for **"SonarQube for IDE: Analyze all files in folder"** (or similar — wording varies by extension version)
- **All open files:** Command Palette → **"SonarQube for IDE: Analyze all open files"**
- **Just open the file:** Opening any `.ts` / `.tsx` file in the editor triggers analysis on it within seconds

Running "analyse folder" on `src/` will populate your Problems panel with the same hundreds of issues CI shows — but it takes minutes. That's why it's manual / on-demand, not automatic.

### One subtle thing connected mode DOES do for you

In connected mode, SonarQube for IDE **suppresses issues that have been marked Resolved or False-Positive on SonarCloud**. So if your team triaged "yeah, that's intentional, ignore" on issue X in `Sidebar.tsx`, and you later open `Sidebar.tsx`, the IDE won't show issue X — even though the underlying code pattern is still there. This keeps local noise aligned with the team's curated server state.

But this is the only "cross-pollination" from server state to IDE display. The IDE never pre-populates server-known issues — it only ever suppresses ones already triaged.

---

## What rules does SonarQube for IDE actually use?

Common confusion: does the IDE use my Quality Gate? Quality Profile? Sonar Way defaults? Some mix?

**The IDE uses your Quality Profile. It does NOT use your Quality Gate.** Different things — easy to confuse:

| Concept | What it defines | Used by IDE? |
|---------|----------------|--------------|
| **Quality Profile** | Which rules to RUN (the *checks*) — e.g. "S3358: no nested ternaries", "S125: no commented code" | ✅ Yes (in connected mode) |
| **Quality Gate** | Pass/fail THRESHOLDS on scan results — e.g. "new bugs = 0", "new coverage ≥ 80%" | ❌ No (irrelevant to per-file analysis) |

Why this split makes sense:
- **Profile = WHAT to look for.** This is per-file, per-line — perfectly suited to real-time IDE analysis.
- **Gate = WHEN to fail the build.** This evaluates *aggregate scan metrics* (totals, percentages). The IDE isn't doing a scan, so there's nothing to aggregate. The gate is a CI-time concept.

### The three states your IDE can be in

| State | Rules used | What it means |
|-------|-----------|---------------|
| **Disconnected** (no connection to SonarCloud) | Built-in default ruleset (Sonar Way subset bundled with the extension) | Generic SonarQube user experience. Misses any Mojo Soup customisations. |
| **Connected, profile pulled** | Your `Mojo Soup <Language>` profile | Same rules as CI. Rule activations/deactivations from your custom profile apply. |
| **Connected, with issue sync** | Profile + issue-resolution sync | Profile rules + suppresses issues marked Resolved/False-Positive on the server. This is the normal steady state once connected for a bit. |

To check which state you're in, look at the SonarQube for IDE status bar / output panel in Cursor. It should say "Connected to SonarCloud, project: Mojo-Soup_<repo>". If not, run Command Palette → **"SonarQube for IDE: Connect to SonarQube Cloud"** with connection name exactly `SonarCloud`.

### Why CI might flag issues your IDE missed

Some rules **can only run server-side** — particularly the security-focused ones that need to trace data flow across many files (e.g. "this user input flows into a SQL query 3 functions later"). The IDE doesn't do cross-file analysis, so these rules are skipped locally even though they're in your profile.

Practical implication: if CI flags a SECURITY HOTSPOT or certain types of VULNERABILITY that you didn't see in the IDE, **that's normal**. Those rules genuinely only run server-side. The IDE shows you everything the IDE can analyse — but a small slice of advanced rules is CI-exclusive.

---

## How `/sonar-check` and SonarQube for IDE work together

These are **complementary, not redundant.** Use both.

```
┌─────────────────────────────────────────────────────────────┐
│  As you write code (real-time, on the file in front of you) │
│                          ↓                                  │
│              SonarQube for IDE (Cursor extension)           │
│              Inline squiggles, Problems panel               │
│              Uses Mojo Soup quality profile via             │
│              connected mode                                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
              You push to your branch + raise a PR
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  CI runs (a few minutes, on the full branch / PR diff)      │
│                          ↓                                  │
│              SonarCloud scanner uploads results             │
│              PR decoration posts ✅ or ❌ on the PR         │
└─────────────────────────────────────────────────────────────┘
                          ↓
              You want to check from chat without
              switching to the browser
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  /sonar-check                                               │
│  Reads the latest CI scan results, formats them for chat    │
│  Same data as SonarCloud UI, less clicking                  │
└─────────────────────────────────────────────────────────────┘
```

**Rule of thumb:**
- "Is this LINE I'm typing OK?" → SonarQube for IDE
- "Is the whole BRANCH / PR passing the gate?" → `/sonar-check`

---

## Related skills

- **`/sonar-integrate`** — sets up SonarQube Cloud integration in a new repo. Run once per repo before `/sonar-check` will have anything to report. See its own `README.md` for org-level setup, IDE installation, and quality gate configuration.
- **`/security-review`** — deeper security review of your current diff. Better than `/sonar-check` for security-rated issues because it reasons about attack vectors rather than just matching rule patterns.
- **`/ado-pr`** — when you raise a PR via this skill, it automatically detects whether SonarQube is integrated in the main pipeline and surfaces the status in the PR's QA table. No manual check needed.
