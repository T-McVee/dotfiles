---
name: sonar-integrate
description: Integrate SonarQube Cloud (formerly SonarCloud) into Azure DevOps pipelines for npm, pnpm, and .NET (C#) projects at Mojo Soup. Use this skill whenever the user wants to add SonarQube to a project, set up code quality scanning, wire up SonarCloud / SonarQube Cloud / SonarQube for IDE, enable PR decoration, or says anything like "add sonarqube", "set up sonarcloud", "set up sonarqube cloud", "integrate sonarqube into this repo", "wire up code quality scanning", "add static analysis", "turn on sonar for this project", "add sonarqube for ide config", or "set up sonar for cursor / vs code / rider". Modifies the main-branch pipeline only (dev/preprod/prod pipelines are left alone), creates a sonar-project.properties for non-.NET projects, and commits SonarQube for IDE (formerly SonarLint) connected-mode config so every developer's IDE — VS Code, Cursor, JetBrains, Visual Studio — auto-binds to the right project profile.
---

# SonarQube Cloud Integration

Wires up SonarQube Cloud scanning for a Mojo Soup repository. Touches only the **main-branch** Azure DevOps pipeline (plus PRs targeting main) and adds editor configuration so developers get inline feedback as they code. Dev / preprod / prod pipelines are deliberately left untouched — main is the authoritative quality baseline, and PR decoration covers pre-merge feedback.

The exact pipeline edits depend on the project's ecosystem:

| Ecosystem | Detection signal              | Scanner mode | Coverage format          |
|-----------|-------------------------------|--------------|--------------------------|
| .NET (C#) | `*.csproj` or `*.sln` present | `dotnet` (MSBuild) | OpenCover (`coverage.opencover.xml`) |
| npm       | `package-lock.json` present   | `cli` + `sonar-project.properties` | `lcov.info` |
| pnpm      | `pnpm-lock.yaml` present      | `cli` + `sonar-project.properties` | `lcov.info` |

A monorepo (e.g. C# backend + pnpm frontend) needs both paths applied — process each subproject's main pipeline independently.

**Org-level prerequisites** (Quality Gates, Quality Profiles, the SonarQube Cloud DevOps Platform integration, etc.) are not configurable via pipeline YAML. They live in the SonarQube Cloud UI and only need to be done once per organisation. See `README.md` in this skill for the full org admin setup guide — do **not** create a setup checklist file inside the target repo.

---

## Step 1: Detect the ecosystem(s)

Look in the repo root and one level deep (typical front/back-end splits put projects in subfolders like `csharp/`, `frontend/`, etc.):

- `package-lock.json` → **npm path** (Reference B)
- `pnpm-lock.yaml` → **pnpm path** (Reference C)
- Any `*.csproj` or `*.sln` → **dotnet path** (Reference A)

If a repo has more than one (monorepo), treat each subproject independently. If none match, stop and ask the user which ecosystem to target.

---

## Step 2: Locate the main-branch pipeline ONLY

Find every Azure DevOps pipeline YAML, then filter to only the one(s) that trigger on `main`. Common locations:

- `azure-pipelines*.yml` / `*.yaml` in repo root
- `pipeline/`, `pipelines/`, `Pipelines/` folders (any case)
- Subproject-scoped: `csharp/Pipelines/`, `frontend/pipeline/`, etc.

Use Glob with patterns like `**/azure-pipelines*.yml`, `**/Pipelines/*.yml`, `**/pipeline*/*.yml`.

**Identify the main pipeline:** Read each file's top-level `trigger:` block. The target file is the one that triggers on `main` (and usually has a `pr:` block also targeting `main`). The Mojo Soup convention is `azure-pipelines-main.yml`, but don't rely on the filename — read the YAML.

**Explicitly skip files that trigger only on `dev`, `preprod`, `prod`, `test`, `staging`, etc.** Do not edit those. If asked why, explain: SonarQube runs on the main-branch authoritative scan + PR scans. Once code is in main and flowing to dev/preprod/prod, additional scans add noise without new signal.

If no main-branch pipeline exists, stop and tell the user. The skill assumes one is already there (built/maintained via other Mojo Soup conventions).

---

## Step 3: Check if already integrated (idempotency)

For each main-branch pipeline file, check whether SonarQube tasks are already present. Skip the file if it contains any of:

- `SonarCloudPrepare`
- `SonarCloudAnalyze`
- `SonarCloudPublish`
- `SonarQubePrepare` / `SonarQubeAnalyze` / `SonarQubePublish` (older naming)

If all relevant pipelines are already integrated, report that and exit cleanly.

Also check for an existing `sonar-project.properties` at the repo root or in the subproject folder for npm/pnpm projects. If present, read it and reuse the project key / organisation — don't overwrite.

Also check for existing SonarLint config files (`.sonarlint/connectedMode.json`, `.vscode/settings.json` with `sonarlint.connectedMode.project`, `.idea/sonarlint.xml`). If present and pointing at the right project key, leave them alone. If pointing at a different key, ask the user before overwriting.

---

## Step 4: Determine the project key and name

**Default convention** (matches the existing RoS example):

| Field             | Value                                                    |
|-------------------|----------------------------------------------------------|
| Organisation key  | `mojo-soup`                                              |
| Service connection| `SonarQubeConnection`                                    |
| Project key       | `Mojo-Soup_<repo-name>`                                  |
| Project name      | Human-readable derived from repo name (preserve casing, replace dashes/underscores with spaces) |

**Deriving the repo name:**

```bash
# Best — read from the ADO/Git remote
git config --get remote.origin.url
# Extract the last path segment, strip .git suffix
```

If that fails, fall back to the repo's root folder name.

**Project key substitution rules** (matches how SonarQube Cloud auto-generates keys when importing a repo from ADO):
- Replace spaces with `-`
- Preserve the rest of the repo name as-is
- Project key format: `Mojo-Soup_<repo-name-with-spaces-as-dashes>`

Example: repo `RoS Admin App - Backend` → project key `Mojo-Soup_RoS-Admin-App---Backend` (yes, three dashes — the original ` - ` becomes `---`).

**Confirm with the user** if there's any ambiguity, or if a `sonar-project.properties` already exists with different values.

**Cross-check the org key.** Before continuing, sanity-check that `mojo-soup` is actually the right organisation. Reasons it might not be:
- A second SonarCloud tenant exists (test / sandbox org)
- An existing `sonar-project.properties` in the repo uses a different `organization` value
- An existing `SonarCloudPrepare` task in another pipeline file (e.g. an older `azure-pipelines.yml`) uses a different `organization`

Look for any of those signals in the repo. If `mojo-soup` is contradicted by something already in the repo, **stop and ask the user** which org to use rather than silently producing configs pointing at the wrong tenant. The skill is hard-wired to `mojo-soup` as a default but should not override an existing explicit setting.

---

## Step 4.3: Verify the SonarCloud project actually exists (optional but recommended)

The convention-derived project key from Step 4 (`Mojo-Soup_<repo-name>`) is almost always correct *if* the user followed the standard "Import from Azure DevOps" flow in SonarCloud. But the user may have:

- Manually created the project with a custom key (e.g. lowercase, dashes-only)
- Imported with a different display name
- Not created the project at all yet

If the project key in our pipeline doesn't match an actual SonarCloud project, the first pipeline run fails with a 404 from the SonarCloud API. This step catches that ahead of time.

### Step A — Check if SONAR_TOKEN is available

```powershell
$env:SONAR_TOKEN   # Windows
```
```bash
echo $SONAR_TOKEN  # Mac / Linux
```

**If set:** proceed to Step B (API verification).

**If empty:** offer the user three options, then take their choice:

> "I can verify the SonarCloud project key by querying the API directly, but that needs a personal `SONAR_TOKEN`. Three options:
>
> **A.** Set up `SONAR_TOKEN` now (5 minutes — I'll walk you through it). Best if you'll also use `/sonar-check` later.
> **B.** Skip the verification — proceed with the derived key (`Mojo-Soup_<repo>`) and you'll see at the preview step whether it looks right. If it's wrong, the first pipeline run will fail and we can fix it then.
> **C.** Manually verify — I'll pause, you check SonarCloud's UI for the actual project key, and you tell me if mine is right.
>
> Which do you want?"

**If they pick A — walk them through `SONAR_TOKEN` setup:**

1. Open https://sonarcloud.io/account/security in a browser
2. Sign in with their Mojo Soup account
3. Generate a token named `claude-sonar-integrate` (or similar) — type User Token, 1 year expiry
4. Copy the token immediately (only shown once)
5. Set the env var (detect their OS first):
   - **Windows**:
     ```powershell
     [System.Environment]::SetEnvironmentVariable('SONAR_TOKEN', '<paste-token>', 'User')
     ```
   - **Mac (zsh)**:
     ```bash
     echo 'export SONAR_TOKEN="<paste-token>"' >> ~/.zshrc
     ```
6. **Fully quit + relaunch their editor** (tray Exit on Windows, Cmd+Q on macOS). Reopening a terminal isn't enough — Cursor/VS Code's process tree inherits env vars at app launch.
7. After relaunch, verify with `$env:SONAR_TOKEN` / `echo $SONAR_TOKEN`
8. Re-run `/sonar-integrate` and the skill will continue from this step with the token in hand

For the full walkthrough (with platform-specific edge cases and troubleshooting), point them at the `sonar-check` skill's Step 1 or its README — same setup, both skills use the same env var.

**If they pick B (skip):** continue to Step 4.4 with no verification. Add a note for the eventual Step 10 summary: "Project key not verified against SonarCloud — confirm at preview step."

**If they pick C (manual):** pause and ask them to look up the key:

> "Open https://sonarcloud.io/projects, find your project, and look at the URL — it'll be `?id=<key>`. Or go into the project → Administration → Update Key. Paste the key here, or just say 'matches' if it's the same as `Mojo-Soup_<repo>`."

Use whatever they paste. If they say "matches", proceed with the derived default.

### Step B — Verify the project via the SonarCloud API

If `SONAR_TOKEN` is available, query SonarCloud:

```powershell
$headers = @{ Authorization = "Bearer $env:SONAR_TOKEN" }
$repoName = "<repo-name>"  # the bare repo name without "Mojo-Soup_" prefix
$encoded = [System.Web.HttpUtility]::UrlEncode($repoName)

# Search for projects matching the repo name in mojo-soup org
$response = Invoke-RestMethod "https://sonarcloud.io/api/projects/search?organization=mojo-soup&q=$encoded&ps=25" -Headers $headers
$projects = $response.components
```

```bash
# bash equivalent
ENCODED=$(printf '%s' "$REPO_NAME" | jq -sRr @uri)  # or python urllib.parse.quote
curl -s -H "Authorization: Bearer $SONAR_TOKEN" \
  "https://sonarcloud.io/api/projects/search?organization=mojo-soup&q=$ENCODED&ps=25"
```

**Four possible outcomes** — handle each:

| Result | What to do |
|--------|-----------|
| Exactly one project matches AND its key === derived key | ✅ Silent success. Record `project verified` for the summary. Proceed. |
| Exactly one project matches BUT its key !== derived key | ⚠️ Flag the mismatch explicitly. Tell user: "I derived `<derived-key>` from the repo name, but SonarCloud actually has the project under key `<actual-key>` (name: `<actual-name>`). Use the actual key from SonarCloud?" — wait for confirmation, then use whichever key they pick for all subsequent file edits. |
| Multiple projects match the query | Show the list. Ask the user which one is the target for this repo (or "none of these — create a new one"). Use their pick. |
| Zero projects match | ⚠️ Warn: "No SonarCloud project matches the name `<repo-name>` in the `mojo-soup` org. The first pipeline run will fail at scan upload time unless the project is created beforehand. Either: (a) create the project manually in SonarCloud now and re-run this step, (b) configure SonarCloud to auto-create projects on first scan from ADO (Org → Administration → Project Management → Auto-create projects), or (c) proceed anyway — knowing the first run will likely fail." |
| API returns 401 | Token invalid/expired. Tell user to regenerate at sonarcloud.io/account/security, update env var, fully restart editor. Fall back to "skip" outcome. |
| API returns 403 | Token valid but user lacks access to mojo-soup org. Check they're a member of the org with at least Browser permission. Fall back to "skip" outcome. |
| API returns 5xx / network error | Falls back to "skip" outcome with a note. Don't block the skill on a transient SonarCloud outage. |

After Step B, the skill knows the **definitive** project key to use in all subsequent edits (Step 6 onward), whether that's the derived default or a user-confirmed override.

---

## Step 4.4: Detect & confirm the ADO service connection

The pipeline references a service connection (via the `sonarQubeEndpoint` variable) that must exist in the ADO project. **The Mojo Soup convention is to name it exactly `SonarQubeConnection`**, but some projects may have an existing connection with a different name — don't assume.

If the referenced connection doesn't exist when the pipeline runs, you'll get a confusing error like:

```
There was a resource authorization issue: "The pipeline is not valid. Job Build: Step input SonarCloud references service connection SonarQubeConnection which could not be found."
```

So we detect what's actually there before applying any edits, and use the actual name in the pipeline variable.

### Detect existing connections

First, determine the ADO project name from the git remote:

```bash
git config --get remote.origin.url
# ADO URLs look like:
#   https://Mojo-Soup@dev.azure.com/Mojo-Soup/<PROJECT>/_git/<repo>
# Or older format:
#   https://Mojo-Soup.visualstudio.com/<PROJECT>/_git/<repo>
# Extract <PROJECT>.
```

Then list **all SonarQube/SonarCloud-type** service endpoints in that project (don't filter by name — match by type):

```bash
az devops service-endpoint list \
  --org "https://dev.azure.com/Mojo-Soup" \
  --project "<PROJECT>" \
  --query "[?type=='sonarcloud' || type=='sonarqube'].{name:name, type:type, ready:isReady}" \
  -o json
```

(SonarCloud and SonarQube service connections both use SonarQube tasks in the pipeline — the `type` field distinguishes them but they're functionally equivalent for `SonarCloudPrepare@4` etc.)

### Five possible outcomes, with how to handle each

| Scenario | Detection | Action |
|----------|-----------|--------|
| **Convention match** | One connection found, named `SonarQubeConnection`, `ready: True` | ✅ Use this. Pipeline variable: `sonarQubeEndpoint: 'SonarQubeConnection'`. Record `service connection: ✅ SonarQubeConnection` for summary. |
| **Non-convention name** | One connection found, named something else (e.g. `SonarCloud`, `MojoSonar`, `Sonar`), `ready: True` | ⚠️ Ask the user: "Found an existing SonarQube service connection named `<actual-name>`. Use it as-is, or create a new one called `SonarQubeConnection` (the Mojo Soup convention)?" If they pick "use as-is" → use `sonarQubeEndpoint: '<actual-name>'` in the pipeline. If they pick "convention" → stop and give them creation steps below, then re-run skill. |
| **Multiple connections** | Two or more SonarQube/SonarCloud connections in the project | Show all of them. Ask user which is for this repo (or "none of these — create a new one"). Use their pick in the pipeline variable. |
| **Connection exists but broken** | One connection, `ready: False` | Warn — connection exists but is in a broken state (expired token, revoked auth). Direct user to ADO → Project Settings → Service Connections → click the connection → re-authorise with a fresh token. Stop until they confirm it's working. |
| **Nothing found** | Zero SonarQube/SonarCloud-type connections in the project | Stop. Tell user they need to create one before the pipeline can run. Give creation steps (below). |
| **`az` not authenticated / command errors** | Command fails | Skip the check. Add to summary: "⚠️ Service connection not verified (az CLI not available). The pipeline assumes a `SonarQubeConnection` exists in the ADO project — confirm manually before running." Use the convention name `SonarQubeConnection` in the pipeline. |

### Use the detected name throughout the rest of the skill

Whatever name you settled on, **that's the value that goes into the `sonarQubeEndpoint` variable** in the pipeline edits (Reference A / B / C). For example, if the existing connection is called `SonarCloud`, the pipeline should reference:

```yaml
variables:
  sonarQubeEndpoint: 'SonarCloud'
```

…not the hardcoded `SonarQubeConnection`. The Reference sections show the convention name as a placeholder — substitute the actual detected name when applying edits.

### Creation steps (give the user if connection is missing)

UI-only — can't be done from this skill:

1. Generate a SonarQube Cloud token at https://sonarcloud.io/account/security — name it `ADO Service Connection`, type: User Token
2. In Azure DevOps → open the ADO project → **Project Settings** (bottom left) → **Service connections** → **New service connection**
3. Pick **SonarQube** as the type (NOT "SonarCloud" if that option still appears — it's deprecated; SonarQube is the unified type that handles both server and cloud)
4. **Server URL:** `https://sonarcloud.io`
5. **Token:** paste the token from step 1
6. **Service connection name:** exactly `SonarQubeConnection` — this is the Mojo Soup convention. Following it means future pipelines / repos can reference the same name without per-repo overrides.
7. **Grant access permission to all pipelines:** ✅ (or set up per-pipeline approvals if security policy requires it)
8. Save

One-time setup per ADO project. Multiple repos in the same project share the same connection.

---

## Step 4.5: Verify coverage tooling (.NET only)

The most common SonarQube failure on Mojo Soup .NET repos is **`new_coverage: 0%`** failing the quality gate — not because there's no test code, but because the test project doesn't have **coverlet** installed and so no coverage file is produced. The pipeline's `--CollectCoverage=true` arguments silently do nothing without coverlet.

For each `*Tests.csproj` / `*Test.csproj` / `*.Tests.csproj` found in the repo:

1. Read the file
2. Grep for a `<PackageReference>` to one of:
   - `coverlet.collector`
   - `coverlet.msbuild`
3. Record the result

**If coverlet IS already referenced in every test project** → continue to Step 5 with a one-line confirmation in the eventual summary (`coverage tooling: ✅ coverlet present`).

**If coverlet is missing from one or more test projects** → stop and tell the user explicitly. Show them a list of test projects missing it, then offer:

> "Without coverlet, your pipeline produces no coverage data and SonarQube's `new_coverage` condition will always fail at 0%. I can add `coverlet.msbuild` to the affected test project(s) now, or you can skip this and add it later (your gate will fail on coverage until you do, unless you've removed that condition).
>
> Add `coverlet.msbuild` now? [y/n]"

If yes, add this `<PackageReference>` block inside the existing `<ItemGroup>` that holds the test framework references (typically xunit + Microsoft.NET.Test.Sdk):

```xml
<PackageReference Include="coverlet.msbuild" Version="6.0.2">
  <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
  <PrivateAssets>all</PrivateAssets>
</PackageReference>
```

If they decline, note in Step 10's summary that coverage will be 0% until coverlet is added, and that the gate's coverage condition should be loosened or removed in the meantime.

**Why `coverlet.msbuild` not `coverlet.collector`?** The Mojo Soup convention pipeline uses MSBuild-style coverage args (`/p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:CoverletOutput=...`). These only work with `coverlet.msbuild`. The collector variant uses a different invocation (`--collect:"XPlat Code Coverage"`). Stick with `msbuild` to match the existing pipeline pattern.

This step does not apply to npm/pnpm projects — their coverage tooling (Jest's `--coverage`, Vitest's `--coverage.reporter=lcov`) is built into the test framework, no extra package needed.

---

## Step 5: Preview changes

Show the user a diff-style preview for everything that will change:

```
csharp/Pipelines/azure-pipelines-main.yml [dotnet]
  Insertion point: after 'Restore', before 'Build'
  + variables.sonarQubeEndpoint = 'SonarQubeConnection'
  + checkout step: ensure fetchDepth: 0
  + task: SonarCloudPrepare@4 (scannerMode: dotnet)
  + task: SonarCloudAnalyze@4 (after Test)
  + task: SonarCloudPublish@4 (after Analyze)

frontend/pipelines/azure-pipelines-main.yml [pnpm]
  + task: SonarCloudPrepare@4 (scannerMode: cli, configMode: file)
  + task: SonarCloudAnalyze@4 (after build/test)
  + task: SonarCloudPublish@4

frontend/sonar-project.properties [NEW FILE]
  + projectKey: Mojo-Soup_<repo>
  + organization: mojo-soup
  + sources, exclusions, lcov coverage path

.sonarlint/connectedMode.json [NEW FILE]
  + sonarCloudOrganization: mojo-soup
  + projectKey: Mojo-Soup_<repo>

.vscode/settings.json [MERGE]
  + sonarlint.connectedMode.project
```

Wait for confirmation before writing.

---

## Step 6: Apply pipeline changes (per ecosystem)

Edit each main-branch pipeline file per the matching reference section below. Work file by file. After each edit, re-read to confirm step order and indentation.

- **.NET** → Reference A
- **npm** → Reference B
- **pnpm** → Reference C

---

## Step 7: Create sonar-project.properties (npm / pnpm only)

For npm and pnpm projects, create `sonar-project.properties` at the subproject root (or repo root for single-project repos). Skip if one already exists. See Reference D.

.NET projects do not use this file — `SonarCloudPrepare@4` with `scannerMode: dotnet` reads everything from the `.csproj` and the `extraProperties` block in the pipeline.

---

## Step 8: Set up SonarLint connected-mode config

Create the IDE binding files so every developer who opens the repo with SonarLint installed gets the right project + quality profile automatically. See Reference E.

**Files to create / merge:**

- `.sonarlint/connectedMode.json` — cross-IDE shared binding (newer SonarLint)
- `.vscode/settings.json` — merge in the `sonarlint.connectedMode.project` block (don't clobber existing settings)
- `.idea/sonarlint.xml` — only if the repo already has a `.idea/` folder (i.e. someone uses JetBrains IDEs). Don't create `.idea/` from scratch.

**.gitignore check:** the files we're committing are **shared team config, not secrets** — `connectedMode.json` is just an org name + project key (both public on SonarCloud), and `.vscode/settings.json` is just the SonarLint binding. They need to be tracked so every dev who clones the repo gets the connection automatically.

The skill **does not add new ignore rules** for any of these paths. It only adds **exceptions** when an existing rule would silently exclude one of the files we just committed.

Read the repo's `.gitignore` (and any nested `.gitignore` files) and look for patterns that would exclude what we just wrote:

| If `.gitignore` already contains... | What it means | Add this exception |
|---|---|---|
| `.vscode/` or `.vscode/*` | The default .NET / Node gitignore templates ignore `.vscode/` because it usually holds per-developer IDE state | `!.vscode/settings.json` |
| `.sonarlint/` or `.sonarlint/*` | Older SonarLint versions kept per-developer work files here; some template gitignores blanket-ignore it for that reason. The `connectedMode.json` file is the modern shared-binding exception | `!.sonarlint/connectedMode.json` |
| `.idea/` or `.idea/*` | Standard for JetBrains repos that don't share IDE config — most Mojo Soup repos | `!.idea/sonarlint.xml` (only if you created that file in Step 8) |
| Broad globs like `*lint*` (rare but seen) | A previous attempt at suppressing lint configs | Add explicit exceptions for the specific files |

**Use the specific-file exception pattern (`!path/to/file`), never unignore the whole folder.** This preserves the original ignore rule's intent (e.g. .vscode/ contents stay per-developer) while letting the one shared config file through.

**Ordering matters in `.gitignore`.** Later rules win, so exceptions must appear **after** the broader ignore rule. If you see `.vscode/` on line 5 and `!.vscode/settings.json` on line 3, the exception won't take effect. Append exceptions at the bottom or directly under the matching ignore rule.

**Verification.** After editing `.gitignore`, run:

```bash
git check-ignore -v .sonarlint/connectedMode.json .vscode/settings.json
```

For each file, the command should either print nothing (file isn't ignored — good) or print the negation rule that's keeping it included (e.g. `.gitignore:42:!.vscode/settings.json`). If the output shows a normal ignore rule, the exception isn't working.

---

## Step 9: Verify

After all edits:

1. **YAML parse check** per modified pipeline file:
   ```bash
   python3 -c "import yaml; yaml.safe_load(open('PATH'))" && echo OK
   ```
   On Windows without Python, use PowerShell with the `powershell-yaml` module if available, otherwise visually confirm indentation matches surrounding steps.

2. **Step order check** for .NET:
   - `checkout` (with `fetchDepth: 0`) → `UseDotNet` → `Restore` → `SonarCloudPrepare` → `Build` → `Test` → `SonarCloudAnalyze` → (publish/artifacts) → `SonarCloudPublish`

3. **Step order check** for npm/pnpm:
   - `checkout` (with `fetchDepth: 0`) → `Node`/`pnpm` install → `SonarCloudPrepare` → `build` → `test` (with coverage) → `SonarCloudAnalyze` → `SonarCloudPublish`

4. **Properties file sanity check** (npm/pnpm): `projectKey`, `organization`, `sources` all present.

5. **SonarLint config sanity check**: project key in connected-mode files matches the pipeline.

---

## Step 10: Summary

Report:

### Changes applied
- Each pipeline file modified, with its ecosystem path
- Any new files created (`sonar-project.properties`, `.sonarlint/connectedMode.json`, `.vscode/settings.json` merges, `.idea/sonarlint.xml`)
- Any test projects updated with coverlet (from Step 4.5)
- The project key + name used
- Coverage tooling status: `✅ coverlet present` / `⚠️ coverlet missing — gate will fail on coverage` / `n/a (npm/pnpm — built-in)`

---

### ⚠️ The most important thing to know about your first scan

**SonarCloud will auto-create this project at first scan. The Quality Gate it picks is whatever is set as the org default at scan time.** If you haven't already set your Mojo Soup gate as the org default, the project will be locked to "Sonar way" — and every scan after that will display gate results evaluated against Sonar way's thresholds, not yours.

**Worse: gate evaluation is baked into each scan.** Changing the gate assignment later does NOT retroactively update the displayed result. You have to **re-run the pipeline** for the new gate to take effect.

So **before** the first scan completes, work through the action items below in order. They're sequenced to avoid the trap.

---

### Action items in SonarQube Cloud (UI-only, can't be done from YAML)

Do these in **strict order**. Steps 1 and 2 are one-time per organisation — once done, they benefit every future repo and you can skip them on subsequent runs of this skill.

**1. (One-time, org-wide) Set your Mojo Soup Quality Gate as the org default**

- SonarCloud → click org name top-left → **Quality Gates**
- Find your `Mojo Soup Gate` (or whatever you named it) → click **"Set as Default"**
- Verify the `Default` tag appears next to it
- **Why first:** every project imported from now on inherits this gate automatically. If you skip this step, the first scan will assign "Sonar way" to the project and you'll have to fix it manually per-project forever.

**2. (One-time, org-wide) Confirm SonarQube Cloud ↔ ADO DevOps Platform integration**

- SonarCloud → org name → **Administration** → **DevOps Platform Integrations** → **Azure DevOps**
- Confirm there's a connected ADO instance with a **valid, non-expired PAT**
- PAT scopes required: **Code (Read & Write)** + **Pull Request Threads (Read & Write)**
- **Why this matters:** without it, PR-mode scans fail with `Could not find the pullrequest with key '<id>'`. The scan returns exit code 1 and your pipeline turns red — not because of code, but because the scanner can't authenticate to ADO.
- PATs expire (default 30/60/90 days). When they expire, every PR scan starts failing simultaneously. If multiple repos break at once, this is almost always the cause.

**3. (Per project, AFTER first scan) Confirm the right gate landed**

After the first scan completes:
- Open the new project in SonarCloud → **Administration** → **Quality Gate**
- It should show your Mojo Soup gate. If it shows "Sonar way", step 1 wasn't done before this scan — fix by **"Use a specific gate"** → pick your Mojo Soup gate → save.
- Then **re-run the pipeline** (see "Re-scanning" below) — the displayed gate result won't update until the next scan.

**4. (Per project) Set the New Code definition**

- Project → **Administration** → **New Code**
- Recommended: **"Previous version"** for release-tagged projects, **"Number of days: 30"** for continuous-delivery projects
- **Why this matters:** "New code" is what the quality gate evaluates. Without a sensible definition, the gate either fails on everything (because all existing code is "new") or passes on nothing.

---

### Re-scanning to refresh stale gate results

Gate / new-code / project-config changes don't retro-apply to existing scan results. To re-evaluate against new config **without pushing a commit**:

- **ADO → Pipelines → find the main pipeline → click into the latest run → top-right ⋮ menu → "Run new"** (or "Rerun all jobs")
- Same commit, fresh scan, evaluates against current SonarCloud config
- ~3-5 minutes later, `/sonar-check` and the SonarCloud UI will reflect the new gate

This is the cleanest way to fix "I changed the gate but it still shows the old result."

---

### Reminder for developers

Surface these to the user explicitly — don't bury in a doc link.

**1. Install SonarQube for IDE** (formerly SonarLint) in their editor:
- VS Code / Cursor / VSCodium — Extensions panel → "SonarQube for IDE" by Sonar
- JetBrains (Rider/IntelliJ/WebStorm) — Marketplace → "SonarQube for IDE"
- Visual Studio — Extensions Manager → "SonarQube for IDE: Visual Studio"
- **Name the connection exactly `SonarCloud`** — case-sensitive, must match the committed `.vscode/settings.json` and `.idea/sonarlint.xml`. See the skill `README.md` for full IDE setup walkthrough.

**2. Set up `SONAR_TOKEN`** as an environment variable (only needed for `/sonar-check` mid-development queries):
- Generate a personal token at https://sonarcloud.io/account/security
- **Windows:** run in PowerShell → `[System.Environment]::SetEnvironmentVariable('SONAR_TOKEN', '<token>', 'User')` → fully quit + relaunch the editor (tray Exit, not just close window)
- **Mac:** add `export SONAR_TOKEN="<token>"` to `~/.zshrc` → fully quit + relaunch the editor with Cmd+Q
- Full walkthrough lives in the `sonar-check` skill's Step 1 — point them there if they hit issues.

---

## Reference A — .NET pipeline path

**Prerequisites:** Pipeline already has `dotnet restore`, `dotnet build`, `dotnet test` steps. Tests should produce coverage; if they don't, the skill should ask the user whether to add coverage collection (OpenCover format is required for SonarCloud).

**Variables block** — handle carefully. Three cases:

1. **No `variables:` block exists** → add one at the top of the pipeline:
   ```yaml
   variables:
     sonarQubeEndpoint: 'SonarQubeConnection'
   ```

2. **A `variables:` block exists with mapping-style entries** (most common — `key: value` pairs):
   ```yaml
   variables:
     buildConfiguration: 'Release'
     workingDirectory: 'csharp'
   ```
   → add the new key under the existing block:
   ```yaml
   variables:
     buildConfiguration: 'Release'
     workingDirectory: 'csharp'
     sonarQubeEndpoint: 'SonarQubeConnection'
   ```

3. **A `variables:` block exists with list-style entries** (less common — `- name: ... value: ...` pairs):
   ```yaml
   variables:
     - name: buildConfiguration
       value: 'Release'
   ```
   → add the new entry in the same list style:
   ```yaml
   variables:
     - name: buildConfiguration
       value: 'Release'
     - name: sonarQubeEndpoint
       value: 'SonarQubeConnection'
   ```

**Critical: never create a second `variables:` key.** Two `variables:` blocks at the same level is invalid YAML and the pipeline will fail to parse. After your edit, grep the file for `^variables:` — there must be exactly one match.

**Checkout step** — must use `fetchDepth: 0` for SonarQube blame to work. If a `- checkout: self` step already exists, ensure it has this. If no explicit checkout step exists, add one:

```yaml
- checkout: self
  fetchDepth: 0  # required for SonarQube blame
```

**Insert `SonarCloudPrepare@4` AFTER the Restore step and BEFORE the Build step:**

```yaml
- task: SonarCloudPrepare@4
  displayName: 'Prepare SonarQube Cloud analysis'
  inputs:
    SonarCloud: '$(sonarQubeEndpoint)'
    organization: 'mojo-soup'
    scannerMode: 'dotnet'
    projectKey: 'Mojo-Soup_<repo-name>'
    projectName: '<Human Readable Name>'
    extraProperties: |
      sonar.exclusions=**/*.Tests/**,**/bin/**,**/obj/**
      sonar.cs.opencover.reportsPaths=$(Build.SourcesDirectory)/TestResults/coverage.opencover.xml
```

**Test step coverage** — verify the test step collects OpenCover coverage. If it doesn't, update it:

```yaml
- task: DotNetCoreCLI@2
  displayName: 'Test with coverage'
  inputs:
    command: 'test'
    projects: '$(workingDirectory)/**/*Tests.csproj'
    arguments: '--configuration $(buildConfiguration) /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:CoverletOutput=$(Build.SourcesDirectory)/TestResults/coverage.opencover.xml'
```

This requires `coverlet.collector` (or `coverlet.msbuild`) referenced in the test `.csproj`. If neither is present, flag it in the summary as a follow-up (the scan will still run, just without coverage data).

**Insert `SonarCloudAnalyze@4` AFTER the Test step:**

```yaml
- task: SonarCloudAnalyze@4
  displayName: 'Run SonarQube Cloud analysis'
  condition: succeeded()
```

**Insert `SonarCloudPublish@4` AFTER analyze** (can sit alongside other publish steps; it doesn't publish artifacts, it publishes the Quality Gate result):

```yaml
- task: SonarCloudPublish@4
  displayName: 'Publish SonarQube Cloud Quality Gate'
  condition: succeeded()
  inputs:
    pollingTimeoutSec: '300'
```

**Exclusions guidance:**
- Always exclude test projects (`**/*.Tests/**`, `**/*Test/**`)
- Always exclude `**/bin/**` and `**/obj/**`
- For Azure Functions templates, also exclude any scaffolded `Template.*` test folders specifically named

---

## Reference B — npm pipeline path

**Prerequisites:** Pipeline already has a Node setup task (`NodeTool@0` or similar) and an `npm ci` step. Tests should produce coverage in `lcov.info` format under `coverage/lcov.info` (Jest default; Vitest also supports `--coverage --coverage.reporter=lcov`).

**Variables block** — follow the same three-case handling as Reference A (no block → create; mapping-style → merge; list-style → append). **Never create a second `variables:` key.** After editing, grep the file for `^variables:` — there must be exactly one match.

If the pipeline has no `variables:` block at all, add this at the top:

```yaml
variables:
  sonarQubeEndpoint: 'SonarQubeConnection'
```

**Checkout step** with `fetchDepth: 0`:

```yaml
- checkout: self
  fetchDepth: 0
```

**Insert `SonarCloudPrepare@4` AFTER `npm ci` and BEFORE the build step:**

```yaml
- task: SonarCloudPrepare@4
  displayName: 'Prepare SonarQube Cloud analysis'
  inputs:
    SonarCloud: '$(sonarQubeEndpoint)'
    organization: 'mojo-soup'
    scannerMode: 'cli'
    configMode: 'file'  # reads sonar-project.properties
```

(All project-specific config lives in `sonar-project.properties` — see Reference D.)

**Test step with coverage** — verify the test step produces `coverage/lcov.info`. For Jest:

```yaml
- script: npm run test -- --coverage --coverageReporters=lcov
  displayName: 'Test with coverage'
```

For Vitest:

```yaml
- script: npm run test -- --coverage --coverage.reporter=lcov
  displayName: 'Test with coverage'
```

If the project's `package.json` already has a `test:coverage` script or similar, use that instead.

**Insert `SonarCloudAnalyze@4` AFTER tests:**

```yaml
- task: SonarCloudAnalyze@4
  displayName: 'Run SonarQube Cloud analysis'
  condition: succeeded()
```

**Insert `SonarCloudPublish@4` AFTER analyze:**

```yaml
- task: SonarCloudPublish@4
  displayName: 'Publish SonarQube Cloud Quality Gate'
  condition: succeeded()
  inputs:
    pollingTimeoutSec: '300'
```

---

## Reference C — pnpm pipeline path

Identical to Reference B (npm) except:
- Install step is `pnpm install --frozen-lockfile`, not `npm ci`
- Test command is `pnpm test -- --coverage ...`

The `SonarCloudPrepare@4` / `SonarCloudAnalyze@4` / `SonarCloudPublish@4` tasks themselves are package-manager-agnostic. The `sonar-project.properties` file is identical to the npm case.

---

## Reference D — sonar-project.properties (npm / pnpm only)

Create this file at the subproject root (where `package.json` lives). For monorepos with separate front/back, each subproject gets its own.

```properties
# SonarQube Cloud project configuration
# Generated by the sonar-integrate skill

sonar.projectKey=Mojo-Soup_<repo-name>
sonar.projectName=<Human Readable Name>
sonar.organization=mojo-soup

# Source layout
sonar.sources=src
sonar.tests=src
sonar.test.inclusions=**/*.test.ts,**/*.test.tsx,**/*.test.js,**/*.test.jsx,**/*.spec.ts,**/*.spec.tsx,**/*.spec.js,**/*.spec.jsx

# Exclusions
sonar.exclusions=**/node_modules/**,**/dist/**,**/build/**,**/coverage/**,**/*.d.ts

# Coverage
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.typescript.lcov.reportPaths=coverage/lcov.info

# Source encoding
sonar.sourceEncoding=UTF-8
```

**Adapting to the project:**
- Inspect the project layout — if sources are in `app/` or `lib/` instead of `src/`, update `sonar.sources` accordingly
- If the project doesn't have tests yet, omit the `sonar.tests` and coverage lines and note this in the summary
- For Next.js / SvelteKit / Nuxt projects, also exclude framework-generated folders (`.next/`, `.svelte-kit/`, `.nuxt/`)

---

## Reference E — SonarQube for IDE connected-mode files

These commit the IDE binding for **SonarQube for IDE** (the extension formerly known as SonarLint — rebranded by SonarSource in 2024). The setting keys are still `sonarlint.*` for backward compatibility, so the file contents below are unchanged from the SonarLint era. They're shared config, not local state — commit them.

The same files work for **VS Code, Cursor, VSCodium** (all VS Code forks read `.vscode/settings.json` natively) and **JetBrains IDEs** (read `.idea/sonarlint.xml`).

**File 1: `.sonarlint/connectedMode.json`** (cross-IDE, newer SonarQube for IDE versions):

```json
{
  "sonarCloudOrganization": "mojo-soup",
  "projectKey": "Mojo-Soup_<repo-name>"
}
```

**File 2: `.vscode/settings.json`** — merge into existing settings (do not clobber):

```json
{
  "sonarlint.connectedMode.project": {
    "connectionId": "SonarCloud",
    "projectKey": "Mojo-Soup_<repo-name>"
  }
}
```

If `.vscode/settings.json` doesn't exist, create it with just this block. If it exists, read it, add/update the `sonarlint.connectedMode.project` key, and write it back. Preserve all other settings.

**File 3: `.idea/sonarlint.xml`** — ONLY if `.idea/` already exists in the repo (i.e. JetBrains is in active use). Do not create `.idea/` from scratch.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="SonarLintProjectSettings">
    <option name="bindingEnabled" value="true" />
    <option name="connectionName" value="SonarCloud" />
    <option name="projectKey" value="Mojo-Soup_<repo-name>" />
  </component>
</project>
```

**Connection name caveat:** the `connectionId` / `connectionName` values reference a connection the developer creates inside their IDE (via "SonarQube for IDE: Connect to SonarQube Cloud" or the equivalent for their IDE) the first time they connect. The Mojo Soup convention is to name the connection exactly `SonarCloud` — this string is load-bearing across every repo the skill touches. The skill must mention this in the summary so devs know what to name it.

---

## Notes (cross-cutting)

- **One skill, multiple ecosystems**: A monorepo with separate backend (.NET) and frontend (pnpm) gets both Reference A and Reference C applied to their respective main-branch pipelines. Both subprojects get their own `sonar-project.properties` (for the JS one) and may share a single root-level `.sonarlint/connectedMode.json` *if* SonarQube Cloud has a single project covering both — but the Mojo Soup convention is one SonarQube project per repo/subproject, so usually each gets its own connectedMode.json in its subfolder.
- **Idempotency**: Re-running the skill on an already-integrated repo must be a no-op. Detect existing integration via the signals in Step 3 and skip those files.
- **Never** change trigger branches, pool settings, env vars, or existing artifact names. Only add new SonarQube steps and the variable for the service connection.
- **Quality Gates and Profiles are NOT configurable from this skill.** They live in the SonarQube Cloud UI and are set once per organisation. See `README.md` for the admin setup walkthrough.
- **PR decoration is NOT configured from this skill.** It requires the SonarQube Cloud admin to authorise the ADO DevOps Platform integration once. Once that's done, PR decoration happens automatically for any project scanned from an ADO pipeline.
