---
name: build-artifacts
description: Capture per-build dependency snapshots in Azure DevOps pipelines for npm, pnpm, and .NET (C#) projects. Use this skill whenever the user wants to add build artifact capture, wire up dependency snapshotting to a pipeline, set up CVE traceability per build, or says anything like "add build artifacts", "integrate build-artifacts", "set up dependency snapshots", "track dependencies per build", "capture nuget versions", or "update the pipeline to capture artifacts". Works on Azure DevOps pipeline YAML files across all three ecosystems, including monorepos that mix them.
---

# Build Artifacts Integration

Adds dependency-snapshot capture to every Azure DevOps pipeline YAML in a project so each build has a traceable record of installed package versions. Existing pipeline behaviour is never changed — only new steps are added.

The exact mechanism depends on the project's package manager:

| Ecosystem | Detection signal             | Mechanism                                              |
|-----------|------------------------------|--------------------------------------------------------|
| npm       | `package-lock.json` present  | `@mjsoup/build-artifacts` CLI (published to ADO feed)  |
| pnpm      | `pnpm-lock.yaml` present     | Raw `pnpm` script steps                                |
| .NET      | `*.csproj` or `*.sln` present| Raw `dotnet list package` script steps                 |

A monorepo (e.g. C# backend + pnpm frontend) can have multiple — run the matching path for each subproject's pipelines.

---

## Step 1: Detect the ecosystem(s)

Look in the repo root and one level deep (typical front/back-end splits put projects in subfolders like `csharp/`, `frontend/`, etc.):

- `package-lock.json` → **npm path** (see Reference A)
- `pnpm-lock.yaml` → **pnpm path** (see Reference B)
- Any `*.csproj` or `*.sln` → **dotnet path** (see Reference C)

If a repo has more than one, treat each subproject independently — each ecosystem's pipelines get its own reference section applied.

If none match, stop and ask the user which ecosystem to target.

---

## Step 2: Survey the pipelines

Find every Azure DevOps pipeline YAML. Common locations:

- `azure-pipelines*.yml` / `*.yaml` in repo root
- `pipeline/`, `pipelines/`, `Pipelines/` folders (any case)
- Subproject-scoped: `csharp/Pipelines/`, `frontend/pipeline/`, etc.

Use Glob with patterns like `**/azure-pipelines*.yml`, `**/Pipelines/*.yml`, `**/pipeline*/*.yml`.

Read each file. For each, identify which ecosystem it belongs to (look at the working directory, project file references, or task names — `DotNetCoreCLI@2` ⇒ dotnet, `pnpm` commands ⇒ pnpm, `Npm@1` ⇒ npm).

---

## Step 3: Plan the changes

For each pipeline file, identify:
1. The matching ecosystem (Reference A/B/C)
2. The **insertion point** — for npm/pnpm this is immediately after the install step; for dotnet it's immediately after `Restore` and before `Build`
3. Whether the file is **already integrated** — skip files containing any of:
   - `@mjsoup/build-artifacts` (npm)
   - `pnpm ls --recursive` or `pnpm-dependencies` (pnpm)
   - `nuget-packages.json` (dotnet)

Show the user a diff-style preview for every file to be changed:

```
csharp/Pipelines/azure-pipelines-dev.yml [dotnet]
  After: 'Restore' step
  + script: NuGet snapshot (dotnet list package --format json)
  + script: NuGet vulnerability check (dotnet list package --vulnerable)
  + task: PublishBuildArtifacts (nuget-packages)

frontend/pipeline/azure-pipelines-dev.yml [pnpm]
  After: 'pnpm install' step
  + script: pnpm snapshot (pnpm ls + pnpm audit)
  + task: PublishBuildArtifacts (pnpm-dependencies)
```

Wait for confirmation before writing.

---

## Step 4: Apply ecosystem-specific changes

Edit each pipeline file per the matching reference section below. Work file by file. After each edit, re-read to confirm step order is correct.

---

## Step 5: Verify

After all edits:

1. **YAML parse check** per file:
   ```bash
   python3 -c "import yaml; yaml.safe_load(open('PATH'))" && echo OK
   ```
   On Windows without Python, use PowerShell with the `powershell-yaml` module if available, otherwise visually confirm indentation matches the surrounding steps (typically 2-space indent, `- task:` / `- script:` at the same level as existing steps).

2. **`.gitignore` check** — ensure local-run output is ignored if it gets generated outside CI:
   - npm path: `deps/`
   - pnpm path: `deps/`
   - dotnet path: nothing extra (artifact is built into `$(Build.ArtifactStagingDirectory)` which only exists in CI)

---

## Step 6: Summary

Report:
- Each pipeline file modified, with its ecosystem path
- Any `.npmrc` or `.gitignore` updates
- Any ecosystem-specific warnings raised (lockfile sync, etc.)

---

## Reference A — npm path

**Prerequisites:**

1. `.npmrc` must include the Mojo Soup feed (add it if missing — do not duplicate):
   ```
   @mjsoup:registry=https://pkgs.dev.azure.com/Mojo-Soup/_packaging/mojo-common/npm/registry/
   ```
2. **Install step must be `npm ci`, not `npm install`.** If it's `npm install` (or `Npm@1` with `customCommand: 'install'`), change it to `npm ci`. `npm install` produces unreliable, non-reproducible snapshots in CI.

**Steps to insert after the install step:**

```yaml
- task: npmAuthenticate@0
  inputs:
    workingFile: .npmrc
  displayName: 'Authenticate npm feed'

- script: npx @mjsoup/build-artifacts npm --out deps
  displayName: 'Capture npm dependency artifacts'

- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: 'deps'
    ArtifactName: 'npm-dependencies'
    publishLocation: 'Container'
  displayName: 'Publish npm dependency snapshot'
```

**Output:** `deps/dependencies.json`, `deps/audit.json`, `deps/metadata.json`.

**Lockfile sync warning** — show this after applying npm changes whenever `npm install` was changed to `npm ci`:

> Switching to `npm ci` will fail at pipeline runtime if `package-lock.json` is out of sync. Run `npm install` locally, commit the regenerated lockfile, then push.

---

## Reference B — pnpm path

**Prerequisites:**

- Install step should use `pnpm install --frozen-lockfile` for the same reproducibility reason `npm ci` is required for npm. If it's plain `pnpm install`, change it.

**Steps to insert after the install step:**

```yaml
- script: |
    mkdir -p deps
    pnpm ls --recursive --depth Infinity --json > deps/dependencies.json || true
    pnpm audit --json > deps/audit.json || true
    node -e "const fs=require('fs');fs.writeFileSync('deps/metadata.json',JSON.stringify({node:process.version,pnpm:require('child_process').execSync('pnpm --version').toString().trim(),timestamp:new Date().toISOString(),lockfile:fs.existsSync('pnpm-lock.yaml')},null,2))"
  displayName: 'Capture pnpm dependency artifacts'

- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: 'deps'
    ArtifactName: 'pnpm-dependencies'
    publishLocation: 'Container'
  displayName: 'Publish pnpm dependency snapshot'
```

**Output:** `deps/dependencies.json`, `deps/audit.json`, `deps/metadata.json`.

Notes:
- `pnpm ls` and `pnpm audit` may exit non-zero (peer warnings, audit findings). `|| true` keeps them informational — the JSON is still written. To make CVE findings fail the build, drop `|| true` from the `pnpm audit` line.
- On `windows-latest` pools, swap the `script:` block for a `pwsh:` block and replace `mkdir -p deps` with `New-Item -ItemType Directory -Force -Path deps | Out-Null`. The rest of the commands work as-is under `pwsh`.

---

## Reference C — dotnet path

**Prerequisites:** None. `dotnet list package` is built into the SDK the pipeline already installs to build the project.

**Steps to insert after the `Restore` step and before `Build`:**

```yaml
- script: dotnet list $(projectFile) package --include-transitive --format json > $(Build.ArtifactStagingDirectory)/nuget-packages.json
  displayName: 'NuGet: Snapshot all package versions'

- script: dotnet --version > $(Build.ArtifactStagingDirectory)/nuget-sdk-version.txt
  displayName: 'NuGet: Capture SDK version'

- script: dotnet list $(projectFile) package --vulnerable --include-transitive
  displayName: 'NuGet: Check for known vulnerabilities'
  continueOnError: true  # flip to false to block builds on CVEs
```

Capturing the SDK version alongside the package list is **essential** on .NET 10+ because of NuGet package pruning (see notes below). Without it, the snapshot is ambiguous — you can't tell whether a "missing" package was never referenced or was pruned because the runtime provides it.

**Then add a publish step** so the snapshot is available as a dedicated artifact. Publish a folder (not a single file) so both `nuget-packages.json` and `nuget-sdk-version.txt` ship together. The cleanest pattern is to write both files into a `nuget/` subfolder of the staging directory and publish that folder; if changing the script paths is not desirable, publish the staging directory but constrain the file pattern. Simplest form, placed near any existing `PublishBuildArtifacts@1` step:

```yaml
- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: '$(Build.ArtifactStagingDirectory)/nuget-packages.json'
    ArtifactName: 'nuget-packages'
    publishLocation: 'Container'
  displayName: 'Publish NuGet dependency snapshot'

- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: '$(Build.ArtifactStagingDirectory)/nuget-sdk-version.txt'
    ArtifactName: 'nuget-packages'
    publishLocation: 'Container'
  displayName: 'Publish NuGet SDK version'
```

Publishing both files to the same `nuget-packages` artifact name groups them together in the build artifact UI.

Notes:
- `$(projectFile)` assumes the pipeline defines a `projectFile` variable (most Mojo Soup .NET pipelines do — e.g. `csharp/Template.Functions.csproj`). If not, substitute the explicit project path or `**/*.csproj`.
- If the pipeline already publishes the entire `$(Build.ArtifactStagingDirectory)` as a single artifact (some preprod-style pipelines do this for classic Release pipelines), both files are automatically included — the extra `PublishBuildArtifacts@1` steps are optional in that case. Mention this to the user rather than adding duplicates.
- The vulnerability check uses `continueOnError: true` so it's informational by default. Flip to `false` per environment when ready to enforce — recommend leaving `true` on dev pipelines and flipping to `false` on preprod/main once the current baseline is known clean. On .NET 10+ projects this is much more practical than on older SDKs because pruning eliminates ~70% of false-positive transitive CVE warnings (see pruning note below).

### .NET 10 package pruning — important caveat

Starting with .NET SDK 10, [NuGet package pruning](https://devblogs.microsoft.com/dotnet/nuget-package-pruning-in-dotnet-10/) is **on by default** for projects targeting `net10.0` or later. The .NET runtime ships its own copies of common system packages (`System.Text.Json`, `System.Formats.Asn1`, `System.Diagnostics.DiagnosticSource`, `System.Threading.Channels`, etc.); when these would otherwise resolve as transitive dependencies, NuGet prunes them from the graph entirely.

What this means for the snapshot:

- **`dotnet list package --include-transitive` will show fewer packages** on .NET 10+ than on .NET 8/9 for the same project. Pruned system packages do not appear.
- **The pruned packages are NOT missing at runtime.** They are provided by the runtime itself. The list reflects "what NuGet downloads on top of the runtime" — not "what's loaded into the process."
- **`--vulnerable` results are much cleaner** on .NET 10+. Microsoft reports a 70% reduction in false-positive transitive CVE warnings because patched runtime versions are no longer flagged.
- **Snapshots from different SDK versions are not directly comparable in shape.** A snapshot from a .NET 9 build will list `System.Text.Json` as transitive; a .NET 10 build of the same code will not. This is why capturing `dotnet --version` alongside the package list is required for accurate historical traceability — without it, a future audit cannot tell whether a package was absent or pruned.

---

## Notes (cross-ecosystem)

- **One skill, multiple ecosystems**: A monorepo with separate backend (.NET) and frontend (pnpm) needs both Reference C and Reference B applied to their respective pipeline files. Process them independently.
- **Idempotency**: Re-running the skill on an already-integrated pipeline must be a no-op. Detect existing integration via the signals in Step 3 and skip those files.
- **Never** change trigger branches, pool settings, env vars, or existing artifact names. Only add new steps.
- **Naming consistency**: artifact names are deliberately ecosystem-specific (`npm-dependencies`, `pnpm-dependencies`, `nuget-packages`) so downstream tooling can identify the source without inspecting contents.
