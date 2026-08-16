---
name: ado-beads-pull
description: >
  Import Azure DevOps work items into Beads via bd ado pull. Use when the user
  wants to pull/import ADO user stories (or other work items) into beads, bring
  in a sprint backlog, sync assigned stories, or says things like "pull my sprint
  into beads", "import these ADO stories", "bd ado pull", or "bring in work items
  from DevOps". Guides PAT setup, clarifies scope, queries ADO when needed, and
  generates the exact pull command. Pull-only — never bd ado push unless asked.
---

# Beads ← ADO pull helper

Help Tim import Azure DevOps work items into Beads with `bd ado pull`. **Pull only** — do not run `bd ado push` or bidirectional sync unless Tim explicitly asks.

## Flow

1. Remind about PAT / config
2. Ask what to import (scope)
3. Resolve work item IDs (from Tim, or query ADO)
4. Show the list for confirmation
5. Generate (and optionally run) `bd ado pull …`

---

## Step 1: PAT and config reminder

Before any pull, check and remind:

```bash
bd ado status
```

Expected for Mojo Soup / DDP work:

| Setting | Value |
|---------|--------|
| `ado.org` | `Mojo-Soup` |
| `ado.project` | Project **GUID** (not the display name — parentheses in `Digitial Delivery Platform (DDP)` fail Beads' project-name validator) |
| PAT | `AZURE_DEVOPS_PAT` env var preferred (Work Items: Read & Write). Avoid `bd config set ado.pat` unless Tim wants it stored locally. |

If PAT is missing, tell Tim to export it in **that** shell (do not ask him to paste the token into chat):

```bash
export AZURE_DEVOPS_PAT='…'
bd ado status
```

DDP project GUID (known good):

```text
2d885c5a-d475-462f-9907-03b09be211be
```

If org/project are unset:

```bash
bd config set ado.org "Mojo-Soup"
bd config set ado.project "2d885c5a-d475-462f-9907-03b09be211be"
```

---

## Step 2: Ask what to import

Ask Tim to choose a scope (don't invent a huge pull):

1. **Explicit IDs** — he pastes IDs / URLs
2. **Sprint + assigned to me** — iteration path or sprint board URL
3. **Epic descendants** — epic ID → User Stories under it (hierarchy)
4. **Other WIQL** — he describes filters (type, area, state)

Default type filter unless he says otherwise: **User Story** only (same as the Herdr trial — skip Features/Tasks unless requested).

Also ask:

- Dry-run first? (default **yes** for new scopes)
- Include already-closed items? (default **no**)

---

## Step 3: Resolve IDs

### From URLs / pasted IDs

Extract numeric IDs from `…/_workitems/edit/12345` or bare numbers.

### From a sprint board URL

Example:

`…/_sprints/taskboard/Minor%20Project/…/Sprint%204%20(Logs%20and%20Finance)`

→ iteration path (unescape):

`Digitial Delivery Platform (DDP)\Minor Project\Sprint 4 (Logs and Finance)`

WIQL (assigned to current user, User Stories, under that iteration):

```wiql
SELECT [System.Id], [System.Title], [System.State], [System.IterationPath]
FROM WorkItems
WHERE [System.TeamProject] = 'Digitial Delivery Platform (DDP)'
  AND [System.WorkItemType] = 'User Story'
  AND [System.AssignedTo] = @Me
  AND [System.IterationPath] UNDER '<ITERATION_PATH>'
  AND [System.State] <> 'Removed'
ORDER BY [System.Id]
```

Run via Azure DevOps MCP or:

```bash
ORG="https://dev.azure.com/Mojo-Soup"
PROJ="Digitial Delivery Platform (DDP)"
ADO_RES="499b84ac-1321-427f-aa17-267ca6975798"

az rest --method post --resource "$ADO_RES" \
  --uri "$ORG/$PROJ/_apis/wit/wiql?api-version=7.1" \
  --body @/tmp/wiql.json -o json
```

### From an epic

Recursive hierarchy WIQL for User Stories under epic `<EPIC_ID>`, then collect target IDs (same pattern used for Epic 20832).

---

## Step 4: Confirm the set

Show a short table: `ID | State | Title`. Note count. Mention that pulling Features/Tasks is optional; skipping them causes harmless “failed to resolve dependency” warnings on parent/child links.

If some IDs already exist in Beads (`bd show` / `External:` URL), say so — `bd ado pull` will update linked beads rather than only create.

---

## Step 5: Generate the command

Always print the exact command Tim can run (or run it yourself if PAT is available in the agent shell and he asks):

```bash
# optional preview
bd ado pull <ID> <ID> … --dry-run

bd ado pull <ID> <ID> …

bd dolt push
bd list --status=open
```

After a real pull:

- Expect dependency-resolution warnings if parents/children weren't imported — OK
- Do **not** enrich beads with AC/DoR from ADO (implementer fetches live on pickup)
- Do **not** `bd ado push` unless Tim asks

---

## Out of scope

- Creating or rewriting ADO work items
- Bidirectional sync / pushing local enrichment
- Auto-pulling the entire project backlog without Tim confirming scope
