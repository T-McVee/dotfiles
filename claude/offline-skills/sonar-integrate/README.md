# sonar-integrate Skill — Setup & Reference

This document covers everything the `sonar-integrate` skill **can't** do from a pipeline YAML — the one-time org configuration in the SonarQube Cloud UI, IDE plugin setup for developers, and ongoing tuning. For the procedural skill instructions, see `SKILL.md`.

The skill itself wires up the per-repo pipeline + IDE config. The work in this README is done once at the organisation level and then benefits every repo the skill is run on.

---

## One-time organisation setup (do this first)

Done by the SonarQube Cloud admin in the [SonarCloud UI](https://sonarcloud.io). Order matters — do these in sequence the first time.

### 1. Create / claim the organisation

If not already done:
- Sign in to sonarcloud.io with the SCM account that owns the Mojo Soup ADO/GitHub
- Create an organisation with key `mojo-soup` (this is the value hard-coded into the skill)
- Bind it to the right paid plan tier — the LoC limit must cover all repos you intend to scan

### 2. Connect the DevOps platform (Azure DevOps)

This is the prerequisite for **PR decoration** — inline comments on PRs.

- Org → **Administration** → **DevOps Platform Integrations** → **Azure DevOps**
- Provide a Personal Access Token (PAT) from Azure DevOps with `Code (Read & Write)` scope on the Mojo-Soup organisation
- Save. SonarQube Cloud can now post PR statuses + inline comments

Without this step, PRs will still be scanned but the results only show in the SonarQube UI, not on the PR itself.

### 3. Create the org-wide Quality Profiles

Quality Profiles define **which rules run** per language. SonarQube ships "Sonar way" defaults for each language — they're a sensible starting point. Copy them into Mojo-Soup-owned profiles so you can tune rules without losing the ability to track upstream changes.

For each language Mojo Soup writes (C#, TypeScript, JavaScript, plus any others):

1. **Quality Profiles** → find "Sonar way" for the language → **Copy**
2. Name the copy `Mojo Soup <Language>` (e.g. `Mojo Soup C#`)
3. **Set as default** for the organisation (so new projects pick it up automatically)
4. Leave the ruleset alone for now — tune later as the team gets comfortable

**Tuning later:** when a rule keeps producing noise the team consistently ignores, deactivate it in the profile. When you want to add a stricter rule, activate it. Don't go strict on day one — let the team see what real noise vs. real signal looks like first.

### 4. Create the org-wide Quality Gate

Quality Gates define the **pass/fail criteria** for a scan. The "Sonar way" gate ships sensible defaults focused on **new code only** — this is the right approach.

1. **Quality Gates** → "Sonar way" → **Copy**
2. Name it `Mojo Soup Gate`
3. Set it as the **organisation default**
4. Recommended conditions (all on **New Code**):

| Condition                    | Threshold |
|------------------------------|-----------|
| New bugs                     | = 0       |
| New vulnerabilities          | = 0       |
| New security hotspots reviewed | = 100% |
| New code smells              | None (warn only at first) |
| New coverage                 | ≥ 80% (only if the project has tests) |
| New duplicated lines (%)     | < 3%      |
| New maintainability rating   | A         |
| New reliability rating       | A         |
| New security rating          | A         |

The key insight: **everything gates on new code, not overall code.** This is what makes SonarQube usable on existing codebases — you don't have to fix every legacy issue to ship, you just have to stop adding new ones.

If you have repos with no tests yet, either drop the coverage condition for now or accept that those repos will fail the gate until tests exist. (The skill will note this in its summary when there's no coverage in the pipeline.)

### 5. Set a default "New Code" definition

**Administration** → **New Code** (org level) — pick the default that new projects inherit.

Two sensible choices:
- **Previous version** — new code = everything since the last release tag. Good for projects with discrete releases.
- **Number of days** (30 is a good default) — new code = everything changed in the last N days. Good for continuous-delivery repos.

Per-project overrides are possible; the skill's summary will remind users to set this per-project after first scan.

---

## Per-repo setup (what the skill does)

This is here for reference — the skill does all of this automatically. Knowing the moving parts helps you debug when something doesn't work.

The skill modifies / creates:

| File | Purpose |
|------|---------|
| `<main-branch-pipeline>.yml` | Adds `SonarCloudPrepare`/`Analyze`/`Publish` tasks, ensures `fetchDepth: 0` on checkout |
| `sonar-project.properties` (npm/pnpm only) | Project key, organisation, sources, exclusions, coverage paths |
| `.sonarlint/connectedMode.json` | Cross-IDE SonarLint binding to the SonarQube Cloud project |
| `.vscode/settings.json` (merge) | VS Code-specific SonarLint binding |
| `.idea/sonarlint.xml` (if `.idea/` exists) | JetBrains-specific SonarLint binding |

The first pipeline run after integration will trigger SonarQube Cloud to auto-create the project. The skill assumes the **import from ADO** flow — the project key follows the SonarQube Cloud auto-generated pattern (`Mojo-Soup_<repo-name>`).

If the project doesn't auto-create (e.g. the DevOps Platform integration is misconfigured), create it manually in the SonarQube UI and re-trigger the pipeline.

---

## Developer IDE setup ("SonarQube for IDE", formerly SonarLint)

> **Naming note:** SonarSource rebranded "SonarLint" to **"SonarQube for IDE"** in 2024. The extension, the mechanism, and the settings keys (`sonarlint.*`) are unchanged — only the marketing name moved. Older docs and the connection identifier we use (`SonarCloud`) still work as-is. If something refers to "SonarLint" anywhere in these instructions, it's the same product.

Every developer should install **SonarQube for IDE** once and bind it to SonarQube Cloud. After that, the connected-mode config files committed by the skill auto-bind each repo to the right project + profile.

### VS Code / Cursor / VSCodium

Cursor and VSCodium are VS Code forks — these instructions apply identically. Cursor's extension panel pulls from Open VSX by default; the SonarQube for IDE extension is published there.

1. Install the **SonarQube for IDE** extension (publisher: **Sonar**, formerly **SonarSource**)
   - In VS Code: Marketplace search for "SonarQube for IDE"
   - In Cursor: Extensions panel → search "SonarQube for IDE"
   - If not in your editor's marketplace, download the `.vsix` from sonarsource.com and install via `Extensions: Install from VSIX...`
2. Open Command Palette → start typing **"SonarQube"** or **"Connect"** — pick the connect-to-cloud command (exact wording: `SonarQube for IDE: Connect to SonarQube Cloud`)
3. Generate a token at https://sonarcloud.io/account/security (one-time, name it something like `<your-name>-ide`)
4. Paste the token when prompted
5. **Name the connection `SonarCloud`** — this exact string matches the `connectionId` in every Mojo Soup repo's committed `.vscode/settings.json`. Don't change it.
6. Open any Mojo Soup repo where the skill has been run — SonarQube for IDE will auto-bind to the project. Look for the binding status in the bottom status bar / output panel.

### JetBrains (Rider / IntelliJ / WebStorm)

1. Install the **SonarQube for IDE** plugin from JetBrains Marketplace (formerly "SonarLint")
2. Settings → **Tools** → **SonarQube for IDE** → **+ Add Connection** → SonarQube Cloud
3. Paste a SonarCloud token (generated at sonarcloud.io/account/security)
4. **Name the connection `SonarCloud`** — must match `.idea/sonarlint.xml` exactly
5. Open any Mojo Soup repo — the committed `.idea/sonarlint.xml` (if present) auto-binds it

### Visual Studio (for .NET devs)

1. Install the **SonarQube for IDE: Visual Studio** extension via Extensions Manager (formerly "SonarLint for Visual Studio")
2. Tools → **SonarQube for IDE** → **Connect to SonarQube Cloud**
3. Token + connection name `SonarCloud`
4. Bind the solution to the matching SonarQube project (Visual Studio's plugin doesn't read `.sonarlint/connectedMode.json` reliably yet — the binding is per-solution and stored in `.vs/` or `.sonarlint/` depending on version)

### What devs get from connected mode

- Real-time inline warnings as they type, using **the same rules as CI**
- Issues already marked resolved / false-positive on the server don't show locally
- Their local "Sonar way" defaults are replaced by `Mojo Soup <Language>` profile rules
- They don't have to wait for a PR scan to see what SonarQube will flag
- **AI CodeFix** suggestions on supported languages (newer feature in SonarQube for IDE)
- Detection works on AI-generated code too (Cursor users — relevant since Cursor writes a lot of code)

---

## Developer setup — `SONAR_TOKEN` (for the `/sonar-check` skill)

The `/sonar-check` skill queries SonarQube Cloud's API to report your current branch's quality gate status in chat — useful mid-development without leaving the editor. It needs a **personal API token** in an environment variable named `SONAR_TOKEN`.

This is a per-developer, one-time setup. Once it's done, `/sonar-check` "just works" for every Mojo Soup repo with SonarQube integrated.

### Step 1: Generate the token (any OS)

1. Open https://sonarcloud.io/account/security in a browser (sign in with your Mojo Soup SCM account)
2. Under **"Generate Tokens"**:
   - **Name:** `claude-sonar-check` (or any label you'll recognise later)
   - **Type:** User Token (default)
   - **Expires in:** 1 year (renewable)
3. Click **Generate**
4. **Copy the token immediately** — SonarCloud only shows it once. If you lose it, revoke and regenerate.

### Step 2a: Windows — set as User env var

Open any PowerShell window and run:

```powershell
[System.Environment]::SetEnvironmentVariable('SONAR_TOKEN', 'PASTE-YOUR-TOKEN-HERE', 'User')
```

Replace `PASTE-YOUR-TOKEN-HERE` with your actual token. Keep the quotes.

Then **fully quit your editor** (Cursor / VS Code — right-click tray icon → Exit, not just close the window) and reopen. Verify with:

```powershell
$env:SONAR_TOKEN
```

It should print your token.

**Why the env var route, not a file?** The Windows User-scoped env var works in PowerShell, cmd, git bash, and integrated terminals across every editor — set once, used everywhere. Persists across reboots. No file to maintain or accidentally commit.

### Step 2b: macOS — add to shell profile

Find your shell:
```bash
echo $SHELL
```

For zsh (default on Catalina+):
```bash
echo 'export SONAR_TOKEN="PASTE-YOUR-TOKEN-HERE"' >> ~/.zshrc
```

For bash:
```bash
echo 'export SONAR_TOKEN="PASTE-YOUR-TOKEN-HERE"' >> ~/.bash_profile
```

Then **fully quit Cursor / VS Code** with `Cmd+Q` (window close on macOS doesn't quit the app) and reopen. Verify with:

```bash
echo $SONAR_TOKEN
```

### Step 2c: Linux — add to shell profile

```bash
echo 'export SONAR_TOKEN="PASTE-YOUR-TOKEN-HERE"' >> ~/.bashrc
```

Restart terminals + editor.

### Common gotchas

| Symptom | Cause | Fix |
|---------|-------|-----|
| `$env:SONAR_TOKEN` empty after setting it | Only closed the terminal panel, not the editor | **Fully quit** the editor app (tray Exit on Windows / Cmd+Q on macOS) — closing windows isn't enough; child processes inherit the env at editor launch |
| `/sonar-check` returns 401 Unauthorized | Token expired or was revoked | Regenerate at sonarcloud.io/account/security, update the env var |
| `/sonar-check` returns 403 Forbidden | Token belongs to a different SonarCloud org, or your user lacks access | Generate the token while signed in to the Mojo Soup org |

### Hygiene

- **Never commit this token.** Not in `.env`, not in `appsettings.json`, not in a config file in any repo. Env vars only.
- **It's personal** — don't share with teammates. They generate their own. Audit logs attribute API calls to the token owner.
- **Rotate if compromised.** Revoke at sonarcloud.io/account/security → generate new → update env var.

---

## PR decoration (how it shows up)

Once the DevOps Platform integration is configured (org setup step 2) and the pipeline has the SonarQube tasks (skill output), every PR to `main` automatically gets:

1. A **Quality Gate status check** at the bottom of the PR page (pass/fail)
2. **Inline comments** on changed lines for each new issue
3. A **summary comment** with totals (new bugs, vulnerabilities, code smells, coverage on new code)

If PR decoration isn't appearing:
1. Check that the org's ADO PAT (set in step 2) hasn't expired
2. Check that the pipeline ran successfully on the PR (look for SonarQube task logs in the build)
3. Check that the project's "Pull Request decoration" toggle is enabled in the project settings on SonarCloud

---

## Troubleshooting

### "Project key already exists with different config"

The skill detected an existing `sonar-project.properties` or pipeline integration with a project key that doesn't match the derived one. Options:
- Keep the existing key (skill will use it as-is)
- Rename the SonarQube Cloud project to match the new convention (in the SonarCloud UI: Project → Administration → Update Key)

### "Quality gate failed but I can't see why"

Run `/sonar-check` (the sibling skill) to query the API directly, or open the project in SonarCloud and look at the "Conditions" tab on the latest analysis. The most common failure is **new coverage** below threshold — usually because new code was added but the corresponding tests weren't.

### "PR comments aren't appearing on the PR"

Check the SonarQube Cloud task logs in the ADO build. Look for `Quality Gate result` — if it's there, scanning worked. If decoration isn't appearing despite a successful scan, it's almost always the ADO PAT (expired / wrong scope).

### ".NET 10 SDK with 0 coverage in SonarCloud"

The OpenCover path in the pipeline must match where the test step actually writes the file. The skill defaults to `$(Build.SourcesDirectory)/TestResults/coverage.opencover.xml` — if your test step writes elsewhere, update both the test step and the `sonar.cs.opencover.reportsPaths` line in `SonarCloudPrepare`.

### "SonarQube for IDE shows different issues than CI"

Almost always means the developer's IDE isn't actually in connected mode. Steps:
1. In their IDE, check the SonarQube for IDE status bar / output panel — it should say "Connected to SonarQube Cloud, project: Mojo-Soup_<repo>"
2. If not, re-run the connect-to-cloud flow
3. Confirm the connection name is exactly `SonarCloud` (case-sensitive in some versions). This string is load-bearing — it's hardcoded into every repo's `.vscode/settings.json` and `.idea/sonarlint.xml` by the skill. Don't rename it locally.

### "I'm on Cursor and the extension isn't in the marketplace"

Cursor pulls from Open VSX by default, where SonarQube for IDE is published. If it doesn't appear:
1. Download the latest `.vsix` from https://www.sonarsource.com/products/sonarlint/ide-login/vscode/
2. Cursor: Command Palette → `Extensions: Install from VSIX...` → pick the file
3. Reload the window
4. Then continue with the connect-to-cloud flow

---

## What this skill deliberately does NOT do

- **Does not scan dev / preprod / prod pipelines** — main + PRs are the authoritative scans
- **Does not create Quality Gates or Profiles** — these are org-level UI-only config (see "One-time organisation setup" above)
- **Does not configure PR decoration** — that's a one-time org setup
- **Does not generate personal SonarQube tokens** — devs make their own
- **Does not enforce vulnerability gates** — the `dotnet list package --vulnerable` and `npm/pnpm audit` checks live in the `build-artifacts` skill. SonarQube focuses on code quality + security hotspots; CVE checks are dependency-graph checks (different signal source)

---

## Related skills

- **`build-artifacts`** — captures per-build dependency snapshots and CVE state. Complementary to SonarQube: build-artifacts answers "what dependencies shipped"; SonarQube answers "what code quality / security issues exist." Both should run on the main pipeline.
- **`sonar-check`** — sibling skill that queries SonarQube Cloud during development for the current branch's analysis. Useful mid-coding without leaving the editor.
- **`ado-pr`** — automatically checks every PR for SonarQube integration in the main-branch pipeline and surfaces an informational row in the QA table (`✅ SonarQube integrated` or `ℹ️ Not integrated — consider sonar-integrate skill`). Purely informational — never blocks PR creation. This is the feedback loop that surfaces repos which haven't been onboarded yet.
