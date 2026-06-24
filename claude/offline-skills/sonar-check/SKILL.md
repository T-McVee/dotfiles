---
name: sonar-check
description: Query SonarQube Cloud (formerly SonarCloud) for the current branch's analysis status without leaving the editor. Use this skill whenever the user wants to check SonarQube during development, see the latest scan result for their branch, check the quality gate before raising a PR, or says anything like "check sonar", "what does sonarqube say", "sonar status", "sonarcloud status", "sonarqube cloud status", "any sonar issues on my branch", "check the quality gate", "did sonar pass", "sonar-check", or "what's sonar saying about my branch". Reports quality gate result, key metrics (bugs, vulnerabilities, code smells, coverage, duplications), and the top open issues with file:line references. Read-only — does not modify the repo. Complements the SonarQube for IDE (formerly SonarLint) extension by showing the server-side analysis from CI, not just local rules.
---

# SonarQube Cloud Status Check

Reports the current branch's SonarQube Cloud analysis state inline in chat. Designed for mid-development use — "is the quality gate still green?", "what new issues did the last scan flag?", "what should I fix before raising the PR?"

Read-only. Does not modify files. Does not trigger a new scan — reports the **latest analysis already on the server** for the current branch (or PR). To get a fresh scan, push to main or open/update a PR (the pipeline will run the scan).

---

## Step 1: Verify SONAR_TOKEN

This skill needs a personal SonarQube Cloud API token to query the server. It's a **per-developer secret** — never committed to a repo, never shared between devs.

### Check if it's set

**Windows (PowerShell):**
```powershell
$env:SONAR_TOKEN
```

**Mac / Linux (bash / zsh):**
```bash
echo $SONAR_TOKEN
```

If it prints a token → skip to Step 2.

If it's empty → **stop immediately**. Do NOT try to proceed with workarounds (no prompting the user to paste their token into chat, no temp files, no shell exports for this session only). Walk the user through proper setup below — it's a one-time thing, and once it's set, every future `/sonar-check` just works.

---

### Setup walkthrough — first detect the platform

Before giving instructions, identify the user's OS so you give ONE set of steps, not three. Quick detection:

- **Windows** — `$env:OS -eq 'Windows_NT'` returns true, or PowerShell prompt visible, or paths use `\`
- **macOS** — `uname -s` returns `Darwin`, or paths look like `/Users/<name>`
- **Linux** — `uname -s` returns `Linux`, or paths look like `/home/<name>`

If still unclear, **ask the user** ("Are you on Windows or Mac?") before continuing.

---

### Part A — Generate the token (same on all OSes)

Tell the user to do this in their browser:

1. Open https://sonarcloud.io/account/security
2. Sign in with their Mojo Soup Azure DevOps / GitHub / Google account if not already
3. Under **"Generate Tokens"**:
   - **Name:** `claude-sonar-check` (or any memorable label — appears in their token list)
   - **Type:** leave as **User Token** (default)
   - **Expires in:** 1 year is sensible — tokens are renewable
4. Click **Generate**
5. **Copy the token immediately** — SonarCloud shows it once, after that it's gone forever. If they lose it, they have to revoke and regenerate.

Wait for the user to confirm they have it copied before moving on.

---

### Part B — Set the env var (platform-specific)

#### If WINDOWS:

The recommended approach is a **User-scoped Windows environment variable**. Works in PowerShell, cmd, git bash, and the integrated terminal inside Cursor / VS Code. Set it once, it persists across reboots.

Tell the user to open any PowerShell window and run:

```powershell
[System.Environment]::SetEnvironmentVariable('SONAR_TOKEN', 'PASTE-YOUR-TOKEN-HERE', 'User')
```

Replace `PASTE-YOUR-TOKEN-HERE` with their actual token. **Keep the quotes.**

Then — and this is the bit people miss:

1. **Close ALL terminal windows** (including the integrated terminal inside their editor)
2. **Fully quit their editor** (Cursor / VS Code) — close window is not enough. Right-click the tray icon → Exit, or `File → Exit`. Cursor's child processes inherit the env vars from when Cursor itself launched, so quitting + relaunching is required to pick up the new value.
3. Reopen Cursor / VS Code
4. In a fresh terminal: `$env:SONAR_TOKEN` should now print the token

**Alternative (GUI):** Press `Win` → type `env` → click **"Edit environment variables for your account"** → under **"User variables"** click **New** → Name: `SONAR_TOKEN`, Value: paste token → OK. Same caveat: fully quit + relaunch the editor.

#### If MAC:

Modern macOS (Catalina+) defaults to **zsh**. First confirm which shell the user has:

```bash
echo $SHELL
```

- `/bin/zsh` (most common) → edit `~/.zshrc`
- `/bin/bash` → edit `~/.bash_profile`

Recommend they run (substituting `~/.zshrc` for bash users):

```bash
echo 'export SONAR_TOKEN="PASTE-YOUR-TOKEN-HERE"' >> ~/.zshrc
```

Replace `PASTE-YOUR-TOKEN-HERE` with their actual token. **Keep the double quotes around the value** — if the token contains special characters, missing quotes will break the export.

Then:

1. **Close ALL terminal windows** including the integrated terminal in their editor
2. **Fully quit their editor** (Cursor / VS Code) with `Cmd+Q` — closing the window is not enough on macOS, the app keeps running
3. Reopen Cursor / VS Code
4. In a fresh terminal: `echo $SONAR_TOKEN` should now print the token

If they don't want to edit `~/.zshrc` for some reason, they can also use macOS's launchd plist mechanism — but that's overkill for a single env var. Stick with the zshrc approach.

#### If LINUX:

Same pattern as macOS but typically `~/.bashrc`:

```bash
echo 'export SONAR_TOKEN="PASTE-YOUR-TOKEN-HERE"' >> ~/.bashrc
```

Restart all terminals and the editor.

---

### Important warnings to surface to the user

Regardless of OS, mention these in the response:

- **Never commit this token.** Not in `.env`, not in `appsettings.json`, not in a config file. It goes in env vars only.
- **The token is yours alone** — tied to your SonarCloud user account. Don't share it with teammates; they generate their own (the whole point of personal tokens is that audit logs attribute API calls to the right person).
- **Revoke if compromised.** Same URL — https://sonarcloud.io/account/security → revoke the token → generate a new one → update the env var.
- **Tokens expire.** If `/sonar-check` starts failing months from now with a 401, regenerate the token and update the env var.

---

### After setup, re-run `/sonar-check`

Once the user confirms they've completed Part A + Part B AND restarted their editor, re-run from the top.

If `$env:SONAR_TOKEN` / `echo $SONAR_TOKEN` is *still* empty after a full restart, the most common cause on Windows is they only closed the terminal pane in Cursor, not Cursor itself. Cursor's process tree is started with the env vars from when the GUI launched. **Full app quit + relaunch is mandatory.**

---

## Step 2: Resolve project key + branch

**Branch:**
```bash
git branch --show-current
```

**Project key** — look in priority order:

1. `sonar-project.properties` at repo root or one level deep — read `sonar.projectKey`
2. Any `azure-pipelines*.yml` file with a `SonarCloudPrepare` task — read `projectKey:` from the `inputs:` block
3. Fall back: derive from `git config --get remote.origin.url` using the convention `Mojo-Soup_<repo-name>` (replace spaces with `-`)

If still ambiguous, ask the user to confirm the project key.

**PR detection** — if the branch isn't `main` and there's an open ADO PR for it, the SonarQube API treats it as a PR analysis. Try to detect via:

```bash
az repos pr list --source-branch <branch> --status active --query "[0].pullRequestId" -o tsv 2>&1
```

**Three possible outcomes, handle each:**

| Outcome | What to do |
|---------|-----------|
| Command succeeds, prints a PR ID | Use `pullRequest=<id>` in all API calls below |
| Command succeeds, prints nothing (no open PR) | Use `branch=<branch>` — branch analysis only |
| Command errors with auth issues (`Please run 'az login'`, `TF400813`, `Token expired`, etc.) | Warn the user **once** with: "Couldn't auto-detect PR (az not authenticated — run `az login` if you want PR-mode results). Falling back to branch analysis." Then continue with `branch=<branch>`. Don't abort the skill. |
| Command errors with project-not-found / repo-not-found | Same fallback — warn once, use `branch=<branch>` |
| `az` not installed at all | Warn once, fall back to `branch=<branch>` |

**Why this matters:** PR-mode and branch-mode return different SonarQube analyses. If the user has an open PR and we fall back to branch mode, they see stale `main`-level results rather than the PR-specific scan. The fallback isn't useless — it's just less precise. Make sure the user knows which mode the report represents (state it explicitly in the final report's header).

---

## Step 3: Query SonarQube Cloud

Base URL: `https://sonarcloud.io/api`

Auth: send the token as HTTP Basic Auth username with empty password — `Authorization: Basic <base64(token:)>`. Or use the bearer-style header `Authorization: Bearer <token>` (SonarCloud accepts both, bearer is cleaner).

**Metric keys to request.** Don't include `alert_status` — it's the quality gate result, which we already get from `project_status` in the first call. Including it here just duplicates the data.

Request these:
```
bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density,security_hotspots,ncloc,new_bugs,new_vulnerabilities,new_code_smells,new_coverage,new_duplicated_lines_density,new_security_hotspots
```

**PowerShell example:**

```powershell
$headers = @{ Authorization = "Bearer $env:SONAR_TOKEN" }
$base = "https://sonarcloud.io/api"
$proj = "Mojo-Soup_<repo>"
$branchOrPr = "branch=$branch"  # or "pullRequest=$prId" if a PR was detected in Step 2

# Quality gate status
$qg = Invoke-RestMethod "$base/qualitygates/project_status?projectKey=$proj&$branchOrPr" -Headers $headers

# Key metrics (no alert_status — redundant with project_status above)
$metrics = "bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density,security_hotspots,ncloc,new_bugs,new_vulnerabilities,new_code_smells,new_coverage,new_duplicated_lines_density,new_security_hotspots"
$m = Invoke-RestMethod "$base/measures/component?component=$proj&metricKeys=$metrics&$branchOrPr" -Headers $headers

# Open issues (top 20 by severity)
$issues = Invoke-RestMethod "$base/issues/search?componentKeys=$proj&resolved=false&s=SEVERITY&asc=false&ps=20&$branchOrPr" -Headers $headers
```

**bash/curl equivalent** (same three calls — pick the right `branch=` or `pullRequest=` parameter based on Step 2):

```bash
# Pick one based on Step 2's PR detection:
SCOPE="branch=$BRANCH"
# SCOPE="pullRequest=$PR_ID"

# Quality gate status
curl -s -H "Authorization: Bearer $SONAR_TOKEN" \
  "https://sonarcloud.io/api/qualitygates/project_status?projectKey=$PROJ&$SCOPE"

# Key metrics
METRICS="bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density,security_hotspots,ncloc,new_bugs,new_vulnerabilities,new_code_smells,new_coverage"
curl -s -H "Authorization: Bearer $SONAR_TOKEN" \
  "https://sonarcloud.io/api/measures/component?component=$PROJ&metricKeys=$METRICS&$SCOPE"

# Open issues
curl -s -H "Authorization: Bearer $SONAR_TOKEN" \
  "https://sonarcloud.io/api/issues/search?componentKeys=$PROJ&resolved=false&s=SEVERITY&asc=false&ps=20&$SCOPE"
```

**Error handling:**

| Response | Meaning | What to do |
|----------|---------|------------|
| 200 with data | Success | Format the report (Step 4) |
| 200 with empty `measures` or `issues` array | Project exists but no analysis on this branch/PR yet | Report "no analysis yet for this branch — push to main or update the PR to trigger a scan" |
| 404 | Project key doesn't exist in SonarCloud, or token doesn't have access to it | Stop — likely a project-key mismatch (re-check Step 2) or token belongs to a different org |
| 401 | Token is invalid, revoked, or expired | Tell the user to regenerate at sonarcloud.io/account/security and update the `SONAR_TOKEN` env var |
| 403 | Token valid but insufficient permissions for this project | Token belongs to a user who isn't a member of the Mojo Soup org, or the project is set to private and the token user isn't on the project |
| 5xx | Server error | Retry once. If it keeps failing, point at https://status.sonarcloud.io |

---

## Step 4: Format the report

Build a concise summary. Don't dump raw JSON.

**Section 1 — Quality Gate** (from `project_status.status`):

```
Quality Gate: ✅ OK  (or ❌ ERROR / ⚠️ WARN)
Branch: <branch>     (or PR #<id>)
Last scan: <date>
```

**Where to get the analysis date:**

1. Primary: `measures/component` response → `component.analysisDate` (ISO 8601 string)
2. Fallback if null/missing: hit `/api/project_analyses/search?project=<key>&branch=<branch>&ps=1` (or `&pullRequest=<id>`) → take `analyses[0].date`
3. If both return nothing: print `Last scan: unknown (no analyses found for this branch/PR)` — don't fabricate a date

Format dates as a short human-readable form (e.g. `2026-05-21 14:32 UTC`), not the raw ISO string.

If the gate failed, list the failing conditions from `project_status.conditions` where `status != OK`:

```
Failing conditions:
  ❌ new_coverage:  62.4%  (threshold: ≥ 80%)
  ❌ new_bugs:      2      (threshold: = 0)
```

**Section 2 — Metrics** (from `measures/component.component.measures`):

```
| Metric                | Overall | New code |
|-----------------------|---------|----------|
| Bugs                  | 4       | 0        |
| Vulnerabilities       | 0       | 0        |
| Code smells           | 137     | 3        |
| Coverage              | 78.2%   | 0%       |
| Duplications          | 1.4%    | —        |
| Security hotspots     | 5       | 0        |
| Lines of code         | 12,403  | —        |
```

Only show rows where data exists (new-code metrics are sometimes empty on `main` scans).

**Section 3 — Top open issues** (from `issues.issues`, top 5-10 by severity):

```
Top issues:
  🔴 BLOCKER  src/services/UsersService.cs:142
              Refactor this method to reduce its Cognitive Complexity from 28 to 15
  🟠 CRITICAL src/Functions/ProcessPermissionChangeFunction.cs:67
              Use a logger to log this exception
  🟡 MAJOR    src/Utilities/JwtTokenHelper.cs:23
              "TODO" tags should be handled
```

Severity icons: 🔴 BLOCKER, 🟠 CRITICAL, 🟡 MAJOR, 🔵 MINOR, ⚪ INFO.

Format each issue as `<icon> <severity>  <file>:<line>` with the message on the next line, indented. Keep messages to one line — truncate if needed.

**Section 4 — Links**:

```
Open in SonarCloud:
  Project:  https://sonarcloud.io/project/overview?id=<projectKey>&branch=<branch>
  Issues:   https://sonarcloud.io/project/issues?id=<projectKey>&branch=<branch>&resolved=false
```

For PRs: `pullRequest=<id>` instead of `branch=<branch>` in the URLs.

---

## Step 5: Optional — suggest fixes

If the user asks "fix these" or "what should I tackle first", offer to:

1. Pick the highest-severity open issues
2. Read the actual source files at the reported line numbers
3. Propose specific code changes

Do **not** auto-apply fixes — issues sometimes have context the API doesn't convey (false positives, intentional patterns). Always propose, get confirmation, then edit.

**For security-rated issues** (severity `BLOCKER` or `CRITICAL` with type `VULNERABILITY` or `SECURITY_HOTSPOT`), recommend running the `/security-review` skill instead of fixing inline. That skill does a deeper pass — checks the whole diff for related issues, looks at attack vectors, considers defence-in-depth — rather than just patching the one line SonarQube flagged. Sonar's signal is a good starting point but it's pattern-based; `/security-review` brings reasoning to the analysis.

**For cognitive complexity / "refactor this method" issues** (common SonarQube finding), check whether the user actually wants to refactor *now* before diving in. A 20-line method at complexity 16 (just over Sonar's 15 threshold) is rarely worth the churn during an unrelated PR — flag it and let them decide.

---

## Notes

- **No new scan triggered.** This skill reads server state. To re-scan, push code (the main pipeline scans on push to main), open/update a PR (PR-mode scan), or re-run the pipeline from ADO (Pipelines → latest run → ⋮ → Run new) — same effect as a push without needing a commit.
- **Displayed gate / metrics lag config changes.** Quality gate evaluation is **baked into each scan at scan time** — changing the gate definition or assignment on SonarCloud doesn't retro-update old scan results. If the user just edited their gate and `/sonar-check` still shows the old verdict, that's why. Tell them to re-run the pipeline (instructions above) and try again after the new scan completes.
- **Token scope.** A user-scope SonarCloud token can read any project the user has access to within the org. Don't share tokens.
- **Rate limits.** SonarCloud API rate limits per token are generous (thousands per hour). This skill makes at most 3 API calls per invocation (4 if it falls back to `project_analyses/search` for the analysis date).
- **PR vs branch analyses are separate.** A branch with an open PR has *both* a branch analysis (from when it was on `main` last) and a PR analysis (from the open PR). The skill prefers the PR analysis if a PR exists — that's the one being decorated on the PR page. State which mode the report represents in the header.
- **No analysis yet?** New branches that haven't been pushed to main and haven't been raised as a PR have no SonarCloud data. The skill will report this cleanly — it's not an error, just "nothing scanned yet for this branch."

---

## Related skills

- **`sonar-integrate`** — sets up the SonarQube Cloud integration in a repo. Run this once per repo before `sonar-check` will have anything to report.
- **`ado-pr`** — when creating a PR, the quality gate result will appear automatically on the PR page (if PR decoration is configured org-wide). `sonar-check` is for pre-PR / during-PR feedback in the chat.
