# Build Artifacts Skill — Output Reference

This document explains what the `build-artifacts` skill produces for each ecosystem, what each output file means, and how to read it. For the procedural skill instructions, see `SKILL.md`.

The skill captures dependency snapshots at build time in Azure DevOps pipelines so every build has a traceable record of installed package versions. The exact files produced depend on the project's package manager.

---

## Ecosystem at a glance

| Ecosystem | Trigger file       | Pipeline artifact name | Output files                                              |
|-----------|--------------------|------------------------|-----------------------------------------------------------|
| npm       | `package-lock.json`| `npm-dependencies`     | `deps/dependencies.json`, `deps/audit.json`, `deps/metadata.json` |
| pnpm      | `pnpm-lock.yaml`   | `pnpm-dependencies`    | `deps/dependencies.json`, `deps/audit.json`, `deps/metadata.json` |
| dotnet    | `*.csproj` / `*.sln`| `nuget-packages`      | `nuget-packages.json`, `nuget-sdk-version.txt`            |

All artifacts are downloadable from the Azure DevOps build summary under "Artifacts."

---

## npm path

Driven by the `@mjsoup/build-artifacts` CLI (published to the Mojo Soup ADO feed) running after `npm ci`.

### Files produced

#### `deps/dependencies.json`
Full `npm ls --all --json` output. This is the complete resolved dependency tree, including every transitive dependency at every depth. Each entry includes:
- Package name and exact resolved version
- Where it sits in the tree (which package required it)
- The version range that was requested vs. what was resolved

**Use it for:** answering "did build #X contain package Y at version Z?" — exact, lockfile-accurate.

#### `deps/audit.json`
Full `npm audit --json` output at the time of the build. Reports known vulnerabilities (advisories) against the resolved tree. Includes:
- Vulnerability ID (GHSA / CVE)
- Severity (low / moderate / high / critical)
- Affected package + version range
- Suggested fix version (if available)
- Whether the vulnerability is in a direct or transitive dependency

**Use it for:** historical CVE traceability — "what was known to be vulnerable at the time we shipped?"

**Note:** the audit is a point-in-time snapshot. New CVEs published after this build won't appear here even if they affect the same packages. To check current vulnerability state, re-run audit against the same `package-lock.json`.

#### `deps/metadata.json`
Small JSON with build context:
- Package name and version (from `package.json`)
- Node.js version that ran the build
- npm version that ran the build
- ISO timestamp of capture
- Working directory path
- Whether a lockfile was present (`package-lock.json` or `npm-shrinkwrap.json`)

**Use it for:** reproducing the build environment, or verifying that the build was lockfile-strict.

### Behaviour notes

- The CLI tolerates non-zero exit codes from `npm ls` and `npm audit` by default (these often exit 1 with valid JSON output — peer dep issues, audit findings). JSON is still written.
- Pass `--fail-on-command-error` to the script step to fail the pipeline on those exits.
- Requires `npm ci` (not `npm install`) for the install step — the skill enforces this. `npm install` produces non-reproducible trees because it can update the lockfile.

---

## pnpm path

Raw `pnpm` commands run after `pnpm install --frozen-lockfile`. No external CLI dependency — uses pnpm built-ins.

### Files produced

#### `deps/dependencies.json`
Output of `pnpm ls --recursive --depth Infinity --json`. Functionally equivalent to npm's dependency tree dump:
- Every direct and transitive dependency
- Exact resolved versions from `pnpm-lock.yaml`
- For monorepos, every workspace package's tree included (`--recursive`)

**Use it for:** same as npm — "exact versions in this build, including transitives."

#### `deps/audit.json`
Output of `pnpm audit --json`. Same shape concept as npm audit:
- Known advisories against the resolved tree
- Severity, affected versions, suggested fixes
- Direct vs. transitive classification

**Use it for:** point-in-time CVE record.

#### `deps/metadata.json`
Inline-generated JSON with:
- Node.js version
- pnpm version
- ISO timestamp
- Lockfile presence (`pnpm-lock.yaml`)

### Behaviour notes

- `|| true` suffixes the `pnpm ls` and `pnpm audit` commands so non-zero exits don't fail the pipeline. JSON is still written.
- To make audit findings fail the build, remove `|| true` from the `pnpm audit` line.
- Requires `pnpm install --frozen-lockfile` (the pnpm equivalent of `npm ci`).

### Why the same file names as npm?

The skill keeps `dependencies.json` / `audit.json` / `metadata.json` consistent across npm and pnpm so downstream tooling that processes "dependency snapshots" doesn't have to branch on package manager. The artifact **name** is different (`npm-dependencies` vs `pnpm-dependencies`) so consumers can identify the producer.

---

## dotnet path

Raw `dotnet` CLI commands run after `dotnet restore` and before `dotnet build`. No external CLI dependency — uses SDK built-ins.

### Files produced

#### `nuget-packages.json`
Output of `dotnet list <project> package --include-transitive --format json`. Structured JSON with:
- Direct package references (from `.csproj` `<PackageReference>` items)
- Transitive packages **that NuGet actually resolved** (see pruning section below — on .NET 10+ this is fewer than you might expect)
- Resolved version per package
- Target framework breakdown if multi-targeted

**Use it for:** "what did NuGet download and link in for this build?"

**What it does NOT include:**
- System libraries shipped *inside* the .NET runtime (these are loaded at runtime but not downloaded — see SDK section)
- Packages pruned because the runtime provides them (.NET 10+ only — see next section)

#### `nuget-sdk-version.txt`
Plain text file containing the output of `dotnet --version` — the SDK version that produced the build, e.g.:
```
10.0.100
```

**Use it for:** identifying which .NET SDK ran the build, which transitively tells you:
- Which runtime BCL versions were available at execution time
- Whether pruning was active (any 10.x = yes; 9.x = no by default)
- Which NuGet client version resolved the graph

**Why this matters:** see ".NET 10 pruning" below — without the SDK version, a dotnet snapshot is ambiguous about what was actually loaded at runtime.

### Behaviour notes

- The vulnerability check step (`dotnet list package --vulnerable --include-transitive`) is informational by default (`continueOnError: true`). It doesn't write its output to a file — results appear in the pipeline log only. This is deliberate: vulnerability state is best re-queried against current advisory data, not captured as a frozen snapshot.
- To turn the vulnerability check into a build gate, flip `continueOnError: false` in the pipeline YAML. Recommended progression: leave `true` on dev pipelines, flip to `false` on preprod/main once the current baseline is known clean.

---

## .NET 9 vs .NET 10 — Pruning explained

This is the single biggest behavioural difference between SDK versions, and the reason `nuget-sdk-version.txt` exists.

### What changed

Starting with **.NET SDK 10**, [NuGet package pruning](https://devblogs.microsoft.com/dotnet/nuget-package-pruning-in-dotnet-10/) is **on by default** for projects targeting `net10.0` or later. Pruning removes from the dependency graph any package that the .NET runtime itself ships.

### Concrete example

Imagine a `.csproj` with these direct references (representative of the RoS backend):
```xml
<PackageReference Include="Microsoft.SharePointOnline.CSOM" Version="16.1.x" />
<PackageReference Include="Microsoft.Identity.Client" Version="4.81.0" />
<PackageReference Include="Serilog" Version="4.3.0" />
<PackageReference Include="Azure.Data.Tables" Version="..." />
```

**On .NET 9 SDK**, `dotnet list package --include-transitive` reports your direct packages plus a long tail like:
```
System.Text.Json 8.0.x
System.Formats.Asn1 6.0.x
System.Diagnostics.DiagnosticSource 8.0.x
System.Threading.Channels 8.0.x
System.Memory 4.5.x
System.Buffers 4.5.x
... (20+ more)
```

**On .NET 10 SDK**, the same command reports your direct packages plus only the transitives the runtime does not ship. The entire `System.*` tail above is **gone from the output**.

### Are those packages missing at runtime?

**No.** They're still loaded into the running process — but the .NET 10 runtime itself provides them as part of the framework, so NuGet doesn't need to download them.

Mental model:
- **.NET 9**: "NuGet downloads everything the app needs."
- **.NET 10**: "The runtime is bigger and provides system packages itself. NuGet only downloads what's on top of that."

The snapshot is therefore answering a slightly different question on .NET 10 — "what did NuGet add on top of the runtime?" rather than "everything resolved."

### Why this is actually good for traceability

- **Third-party packages** (the things you actually care about for CVE traceability — CSOM, MSAL, Serilog, Newtonsoft, Azure SDKs) are **never pruned**. Pruning only touches Microsoft's own system packages.
- **Microsoft system packages** that are pruned are tracked via the SDK version. The SDK release notes list exact BCL versions shipped — that's your audit trail for the runtime-provided stuff.
- **`--vulnerable` is much more useful** on .NET 10. Microsoft reports a ~70% reduction in false-positive transitive CVE warnings because patched runtime versions of system packages no longer get flagged.

### When pruning would be a problem (and why it isn't, for us)

The only forensic question pruning could prevent you from answering is something like:

> "Did build #423 from three months ago contain a vulnerable version of `System.Text.Json` 8.0.4?"

Without the SDK version captured, the snapshot just doesn't list `System.Text.Json` on a .NET 10 build, and you'd be stuck.

**With** `nuget-sdk-version.txt` captured (which the skill produces), you can answer:
1. Read `nuget-sdk-version.txt` → e.g. `10.0.100`
2. Look up the .NET 10.0.100 release notes
3. See which BCL versions shipped (e.g. `System.Text.Json 10.0.0`)
4. Cross-reference against advisory data

So: dependency snapshot + SDK version together = complete traceability. Either alone on .NET 10+ = incomplete.

---

## SDK / Runtime / Framework glossary (dotnet)

Quick reference for the terminology used above.

| Term | What it is |
|---|---|
| **.NET SDK** | The full toolbox installed on the build agent. Contains the `dotnet` CLI, compilers (Roslyn, F#), MSBuild, the NuGet client, *and* the runtime + Base Class Libraries. Version reported by `dotnet --version`. |
| **Runtime** | The execution engine (CLR, GC, JIT) plus the Base Class Libraries that actually run your app. Shipped as part of the SDK. |
| **Base Class Libraries (BCL)** | The `System.*` libraries (`System.Text.Json`, `System.Net.Http`, `System.IO`, etc.) that ship inside the runtime. These are the packages that get **pruned** on .NET 10+ because they're already provided by the runtime. |
| **Target framework** (`net10.0`) | What your `.csproj` declares it builds for. Tells the SDK which runtime version to target. Pruning kicks in when this is `net10.0` or later. |
| **NuGet packages** | Third-party (and some Microsoft) libraries downloaded on top of the runtime. The things `dotnet list package` reports. |
| **Transitive dependency** | A package your code doesn't reference directly but is pulled in because something you reference depends on it. The chief target of pruning. |
| **Pruning** | New default behaviour in SDK 10+ that excludes from the dependency graph any package the runtime already ships. Reduces graph size, restore time, and false-positive CVE warnings. |

---

## How to actually use these artifacts

### To answer "what was in build #X?"

1. Download the artifact (`npm-dependencies` / `pnpm-dependencies` / `nuget-packages`) from the build summary
2. For npm/pnpm: open `dependencies.json` — every direct and transitive package and its resolved version
3. For dotnet: open `nuget-packages.json` for the package list; open `nuget-sdk-version.txt` for the SDK version; cross-reference SDK release notes for runtime-provided BCL versions

### To answer "did build #X contain a vulnerable version of package Y?"

1. Download the artifact
2. Search `dependencies.json` (npm/pnpm) or `nuget-packages.json` (dotnet) for package Y
3. Check the resolved version against the vulnerability advisory
4. For dotnet, if Y is a `System.*` package and not in the file, check the SDK release notes for the version that shipped with that SDK

### To compare two builds

`dependencies.json` and `nuget-packages.json` are both structured JSON — diff them directly with `jq`, `Compare-Object`, or any JSON diff tool. The metadata files (or SDK version file) tell you whether the build environment itself changed between the two.

### To run a fresh audit against an old snapshot

The `audit.json` / vulnerability check log is point-in-time. To check current state, take the lockfile that produced the snapshot (`package-lock.json` / `pnpm-lock.yaml` / the `<PackageReference>` items in `.csproj`), reinstate it locally, and re-run the audit. Combined with the original snapshot, you can see what was vulnerable then vs. what's vulnerable now.

---

## File summary cheat sheet

```
npm-dependencies/                                pnpm-dependencies/
  dependencies.json   ← full npm ls tree           dependencies.json   ← full pnpm ls tree
  audit.json          ← CVEs at build time         audit.json          ← CVEs at build time
  metadata.json       ← node+npm+timestamp         metadata.json       ← node+pnpm+timestamp

nuget-packages/
  nuget-packages.json     ← dotnet list package output (NuGet-downloaded packages only)
  nuget-sdk-version.txt   ← SDK version (needed to interpret pruning on .NET 10+)
```
