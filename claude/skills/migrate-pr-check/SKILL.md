---
name: migrate-pr-check
description: Migrate a legacy pr-check.md file to the new pr-check.yaml format. Invoked automatically by the ado-pr skill when a .md file is found but no .yaml exists.
---

# Migrate pr-check.md to pr-check.yaml

Converts a legacy markdown-format `pr-check.md` into the structured `pr-check.yaml` format.

## Input

You will be given (or should locate) a `pr-check.md` file. It uses a markdown format with two sections:

- **Command Checks** — lines starting with `` ` `` containing shell commands (e.g., `` `npm run lint` ``)
- **Subagent Checks** — bullet list items with a role and description (e.g., `- Security: Review changed files for vulnerabilities...`)

## Output

Write a `pr-check.yaml` file in the same directory as the original `.md` file.

### Mapping rules

1. Each backtick-wrapped command becomes a `commands` entry:
   - `name`: infer from the command — use the script name or tool name (e.g., `npm run lint` → `lint`, `dotnet test` → `tests`, `pytest` → `tests`)
   - `run`: the exact command string

2. Each subagent check becomes a `reviews` entry:
   - `name`: lowercase role name (e.g., `Security` → `security`)
   - `prompt`: the description text after the colon

### Example

**Input** (`pr-check.md`):
```markdown
# PR Checks

## Command Checks
- `npm run lint`
- `npm test`
- `npm run build`

## Subagent Checks
- Security: Review changed files for vulnerabilities — SQL injection, XSS, hardcoded secrets.
- Conventions: Verify new code follows existing patterns.
```

**Output** (`pr-check.yaml`):
```yaml
commands:
  - name: lint
    run: npm run lint
  - name: tests
    run: npm test
  - name: build
    run: npm run build

reviews:
  - name: security
    prompt: Review changed files for vulnerabilities — SQL injection, XSS, hardcoded secrets.
  - name: conventions
    prompt: Verify new code follows existing patterns.
```

## After writing

1. Show the user the new YAML file contents
2. Ask if they want to delete the old `.md` file
3. If they say yes (or this was invoked automatically by `ado-pr`), delete the `.md` file
4. Return control to the calling skill
