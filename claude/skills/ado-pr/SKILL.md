---
name: ado-pr
description: Create a pull request in Azure DevOps. Use this skill whenever the user wants to open, create, or submit a PR, push their work for review, or says anything like "make a PR", "open a pull request", "ship this for review", "ready for review", "submit my changes", or "create a PR". Runs QA checks, generates release notes as the PR body, derives a conventional commit title from the branch history, and links ADO work items found in commits. Always use this skill when the user wants to create a PR in an Azure DevOps repo — even if they don't say "ADO" or "Azure DevOps".
---

# ADO Pull Request Creator

Creates a pull request in Azure DevOps by running QA checks, generating release notes for the PR body, and composing a well-structured PR from the current branch's history.

## Flow overview

1. Verify we're on a suitable branch
2. Run QA checks (if `pr-checks.md` exists)
3. Generate the PR body from release notes
4. Derive a conventional commit PR title from commit history (no scope in title)
5. Extract work item IDs from commits
6. Present the proposed PR to the user and confirm
7. Create the draft PR via `az repos pr create`

---

## Step 1: Verify branch context

```bash
git branch --show-current
git log main..HEAD --oneline --no-merges
```

If you're on `main`, stop — PRs should come from a feature branch. If there are no commits ahead of `main`, stop and tell the user there's nothing to PR.

---

## Step 2: Run QA checks

Look for `pr-checks.md` in the project root, then `.claude/pr-checks.md`.

### If pr-checks.md doesn't exist: create it

Don't skip — offer to create one. First, sniff the project to infer likely commands:

- `package.json` → read the `scripts` field for lint/test/build entries
- `*.csproj` or `*.sln` → `dotnet build` and `dotnet test`
- `pyproject.toml` / `setup.py` → look for pytest, ruff, mypy
- `Makefile` → scan targets for lint/test
- `go.mod` → `go vet ./...` and `go test ./...`

Then ask the user one concise message — something like:

> "No `pr-checks.md` found. Based on your project I'd suggest:
>
> - `npm run lint`
> - `npm test`
>
> Should I also add subagent checks for security and conventions? And is there anywhere else to save this — project root or `.claude/`?"

Use their answer to write `pr-checks.md` to the chosen location. Then proceed with the checks as normal. The file will be there for every future PR on this project.

If the user says they don't want a `pr-checks.md` at all, skip QA checks and continue.

### Running the checks

Read the file and run every check it describes. Checks are typically one of two types:

**Command checks** — bash commands like `npm run lint`, `pytest`, `dotnet test`. Run each with the Bash tool, capture stdout/stderr and exit code.

**Subagent checks** — qualitative analysis tasks like "review for security vulnerabilities", "check for excessive code duplication", or "verify new code follows existing conventions". Spawn these as parallel subagents using the Agent tool. Each subagent should:

- Read the relevant files and the branch diff (`git diff main...HEAD`)
- Produce a concise pass/fail verdict with specific evidence
- Save its result to a temp path so you can read it back

Run all checks regardless of failure — collect every result. After all checks finish, compile a brief summary:

- What passed
- What failed, with a short excerpt of the relevant output (no full log dumps)
- Anything that couldn't run (missing tool, config error, etc.)

You'll present this summary to the user at the confirmation step.

---

## Step 3: Generate PR body

Follow the same approach as the release-notes skill to produce the PR body. Don't write a file and don't stop to ask for adjustments — that review happens at the confirmation step.

```bash
git log main..HEAD --oneline --no-merges
git diff main...HEAD --stat
```

For commits where the message is vague, read the actual diff to understand the change:

```bash
git show <sha> --stat
```

For each commit (or logical group), identify _what changed_ from a user or system perspective — not implementation details:

- Good: "Added validation to the signup form for email and password fields"
- Bad: "Added validateInput() to SignupForm.tsx with regex checks"

Compose a bullet list, grouped logically. No categories, no extra headers. Keep bullets brief — one line each.

The QA results section (built in step 2) will be appended after the release notes. The final body format is:

```markdown
- First change
- Second change
- ...

---

## QA

| Check                 | Result                                       |
| --------------------- | -------------------------------------------- |
| npm run lint          | ✅ PASS                                      |
| npm test              | ✅ Unit Tests (47/47) PASS                   |
| Security agent review | ✅ PASS                                      |
| npm run build         | ⚠️ PASS — chunk size warning (non-blocking)  |
| npm run type-check    | ❌ FAIL — 3 type errors in src/api/client.ts |
```

**Formatting the QA table:**

- For test suite commands, parse the output for a pass count if available — e.g., `Unit Tests (47/47) PASS`, `pytest (12/12) PASS`
- For subagent checks, use the verdict they returned
- For subagent checks, format the name as `{Role} agent review`
- Use ✅ for pass, ⚠️ for pass-with-warnings, ❌ for fail
- Keep the Result column brief — one line. No log dumps in the table.
- Omit this section entirely if no `pr-checks.md` was found and none was created

---

## Step 4: Derive the PR title

```bash
git log main..HEAD --format="%s" --no-merges
```

Synthesize a [conventional commit](https://www.conventionalcommits.org/) title: `<type>: <short description>`

**Type**: pick the one that best represents the bulk of the work — `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`. When there's a mix, prefer the highest-impact type (a branch with one `feat` and three `chore` commits is a `feat`).

**Scope**: Omit the scope.

**Description**: short imperative phrase in lowercase. Adapt from the dominant commit message if one stands out; synthesize if the branch covers multiple things.

Examples:

- `feat: add JWT refresh token support`
- `fix: resolve race condition in concurrent request handling`
- `chore: upgrade to React 18`

---

## Step 5: Extract work item IDs

```bash
git log main..HEAD --format="%s %b" --no-merges | grep -oE '#[0-9]+' | sort -u
```

Strip the `#` prefix — the CLI expects bare numeric IDs.

---

## Step 6: Present and confirm

Show the user:

1. **QA Results** — pass/fail summary (skip this section if no `pr-checks.md` was found). Call out clearly if anything failed.
2. **Proposed PR**:
   - **Title**: the conventional commit title
   - **Body**: the release notes
   - **Work items**: the linked IDs (if any)
   - **Target**: `main` (draft)

Ask: "Does this look good, or would you like to adjust anything?"

If the user wants to change the title, edit the body, or skip a failing check — make those changes before proceeding.

---

## Step 7: Create the PR

Write the PR body to a temp file to handle multi-line content cleanly:

```bash
cat > /tmp/pr-body.md << 'EOF'
{body content here}
EOF
```

Then create the PR:

```bash
az repos pr create \
  --title "{title}" \
  --description "$(cat /tmp/pr-body.md)" \
  --target-branch main \
  --draft \
  --work-items {id1} {id2}
```

Omit `--work-items` if no IDs were found.

After creation, show the PR URL from the output.

---

## Notes

- **Draft by default** — the PR is created as a draft. The user can mark it ready for review in ADO once they're satisfied.
- **ADO CLI prerequisite** — requires the Azure CLI with the `azure-devops` extension (`az extension add --name azure-devops`) and an active login (`az login`). If the command fails for auth or config reasons, surface the error clearly.
- **Missing tools** — if `pr-checks.md` references a tool that isn't installed (e.g., `eslint` not found), note it in the QA summary rather than failing the whole step.
- **See `references/pr-checks-example.md`** for guidance on writing a `pr-checks.md` file for your project.
