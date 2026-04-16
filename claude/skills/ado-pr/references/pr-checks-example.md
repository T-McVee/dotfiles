# pr-check.md — Format Guide

Place this file in your project root (or `.claude/pr-check.md`) to define QA checks that run before a PR is created.

The format is freeform — describe what you want checked in plain language. Command checks are run directly; subagent checks are run by a Claude subagent that reads the diff and relevant files.

---

## Example: Node.js project

```markdown
# PR Checks

## Commands
- `npm run lint`
- `npm test`
- `npm run build`

## Subagent Checks
- Security: Review changed files for common vulnerabilities — SQL injection, XSS, hardcoded secrets, unsafe use of eval or exec, unvalidated user input reaching sensitive operations.
- Duplication: Check for repeated logic across the diff that could be extracted into a shared utility. Flag anything copied more than twice.
- Conventions: Verify that new code follows the patterns established in the existing codebase — naming conventions, error handling style, API response shapes, logging patterns.
```

---

## Example: .NET project

```markdown
# PR Checks

## Commands
- `dotnet build --no-incremental`
- `dotnet test --logger trx`

## Subagent Checks
- Security: Check for insecure deserialization, missing authorization attributes on controllers, sensitive data in logs or exceptions.
- Conventions: Ensure new endpoints follow the existing controller/service/repository pattern. Check that new DTOs match naming conventions in the codebase.
```

---

## Tips

- **Commands** run in the shell exactly as written — make sure they work from the project root.
- **Subagent checks** are run by Claude reading the branch diff and codebase. Be specific about what to look for — the more concrete the description, the more useful the output.
- Checks can be added or removed freely as the project evolves. The skill re-reads the file each time.
- If a command needs a specific working directory or environment variable, add a note — e.g., `cd packages/api && npm test`.
