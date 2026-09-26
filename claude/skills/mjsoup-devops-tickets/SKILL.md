---
name: mjsoup-devops-tickets
description: >
  Mojo Soup Azure DevOps work item skill - writing AND creating well-formed Epics, Features, User
  Stories, Tasks and Bugs in Mojo Soup's Azure DevOps. Covers both how to write the story and
  acceptance criteria content and how to create the items correctly so they do not fail or lose data on
  Mojo Soup's custom fields.

  Trigger whenever the user mentions: "create an epic / feature / user story / task / bug", "write a
  user story", "write acceptance criteria", "Given/When/Then", "add these to DevOps", "build a
  backlog", "raise tickets", "set up the work items", "break this down into stories", or pastes
  requirements / a feature breakdown to be written up or created in Azure DevOps. Also trigger on
  mentions of the Mojo-Soup DevOps org, the Mojility or Mojo-Soup Agile processes, or custom fields
  like User Story detail, Definition of Ready, degree of scope uncertainty, technical complexity, likelihood,
  or test type.

  Use this for both Mojility projects (the default) and the Qld eHealth DSDB Services project.
---

# Mojo Soup - Azure DevOps Work Items

This skill covers writing the content of work items and creating them correctly in Mojo Soup's Azure
DevOps via the **Azure DevOps MCP connector**. Goal: consistently structured, well-written tickets that
use the right fields and do not break on custom fields.

Order of work: pick the project and process, write the content well, put each piece in the right field,
create the hierarchy, then verify.

---

## 1. Environment and processes

| Setting | Value |
|---------|-------|
| Organisation | `https://dev.azure.com/Mojo-Soup/` |
| **Default process** | **Mojility** - used by every project *except* one |
| Exception | `Qld eHealth DSDB Services` is on the **Mojo-Soup Agile** process |
| Primary project for this work | `Digitial Delivery Platform (DDP)` (Mojility; the misspelling is real - copy it exactly) |
| Hierarchy | **Epic -> Feature -> User Story -> Task**, with **Bugs nested under User Stories** |
| Custom Risk type | Planned for the RIOQ register but **not yet created** - do not assume it exists |

**Both processes share the same Mojo Soup custom fields** (User Story detail, Definition of Ready, the
estimating fields, etc.), so the structured format below works on Mojility and Mojo-Soup Agile alike.
Always confirm the **project**, **area path** and **iteration path** before creating; an invalid area
or iteration path fails the create.

---

## 2. Put each piece of content in the right field

This is the most important rule and the one most often gotten wrong. **Do not dump the user story
statement and acceptance criteria into the Description field.** Use the dedicated fields:

| Content | Field (reference name) | Type |
|---------|------------------------|------|
| User story statement (`As a / I want / so that`) | `Custom.UserStorydetail` (display: "User Story detail") | html |
| Definition of Ready (readiness checklist) | `Custom.DefinitionofReady` | html |
| Acceptance criteria (Given/When/Then scenarios) | `Microsoft.VSTS.Common.AcceptanceCriteria` | html |
| Base estimate hours | `Microsoft.VSTS.Scheduling.OriginalEstimate` (the `originalEstimate` param) | number |
| Risk estimating inputs | `Custom.Degreeofscopeuncertainty`, `Custom.Degreeoftechnicalcomplexity`, `Custom.Likelihoodofscopeuncertaintyortechnicalcomplexity` | picklists |

`System.Description` is for supporting context or notes only (for example a clarifying "Note:"), not for
the story statement or the acceptance criteria.

> The field reference names are exact, including `Custom.UserStorydetail` (display "User Story detail")
> and the picklist misspelling `1 - Negligable`. On Mojility (verified on the CESM and RoS projects),
> `Custom.UserStorydetail` and `Custom.DefinitionofReady` are optional, not enforced; populate them
> anyway. Full field detail, allowed values and per-type required fields are in
> `references/custom-fields.md`.

### Which write path to use (check per project)

Whether the connector can write custom and HTML fields depends on the **project**, not the process.
The determinant is whether the connector can resolve that project's work-item-type metadata. Check it
once per project before writing:

**Run `get-work-item-fields(project, "User Story")`.**

- **If it returns the field list** (verified on `Customer and Supplier Management CRM for QH` and
  `Report Once Solution (RoS) for eHealth`, both Mojility, and on `Qld eHealth DSDB Services`): the
  connector can write everything. Set `Custom.UserStorydetail`, `Custom.DefinitionofReady`,
  `Microsoft.VSTS.Common.AcceptanceCriteria` and the estimating picklists via `additionalFields` on
  `create-work-item` / `update-work-item`. Use the full structured create.
- **If it returns NOT_FOUND** (currently the case on `Digitial Delivery Platform (DDP)` only): the
  connector cannot resolve that project's metadata, so **every** `additionalFields` write fails with a
  misleading `FIELD_VALIDATION_ERROR` ("field does not exist on work item type") - including a write to
  the standard `System.Description` field. Use the connector to **scaffold** (title, Description notes,
  priority, estimate, tags, parent links, area, iteration, state), then set the rich fields in the
  **DevOps web UI** (see `references/pitfalls.md` item 3 for the exact UI method). Reads are unaffected:
  `get-work-items-batch` with an explicit `fields` list returns the custom fields fine.

This is a per-project connector issue (most likely a metadata registration or cache problem on a newer
project), **not** a Mojility-wide limitation. Both CESM and RoS are Mojility and work normally; only DDP
currently fails. If DDP starts resolving in `get-work-item-fields`, drop the UI step and use the full
structured create there too - and it is worth asking whoever administers the connector to fix DDP's
metadata resolution.

Either way, do **not** put the story statement or acceptance criteria into Description. Acceptance
criteria always belong in the Acceptance Criteria field. The convenience parameters (title, description,
priority, originalEstimate, remainingWork, storyPoints, tags, areaPath, iterationPath, assignedTo,
state) work via the connector on every project, DDP included.

---

## 3. Writing the content

Write the story and acceptance criteria well before creating. Summary here; full conventions in
`references/writing-stories.md`.

- **User story statement**: `As a [role], I want [capability], so that [benefit].` Use a real named
  role (for example "Investment Lead"), not a bare "user". Always include the "so that" benefit. One
  sentence; if it needs two, split the story.
- **Acceptance criteria**: one or more Given/When/Then scenarios. Cover the happy path, edge cases, and
  failure/error states. One behaviour per scenario; scenarios independently runnable; use exact field
  and status names.
- **Definition of Ready**: a short checklist of what must be true before build starts (fields confirmed,
  data sources agreed, dependencies identified).

For the substance and quality bar of stories and criteria, read `references/writing-stories.md`. Format
the acceptance criteria into the HTML in Section 5 when writing it to the field.

---

## 4. Creating the hierarchy

Use the Azure DevOps MCP tools. The two used most:

- **`create-work-item`** - one item. Required: `project`, `title`, `type`. Convenience params:
  `description`, `originalEstimate`, `storyPoints`, `priority`, `areaPath`, `iterationPath`,
  `assignedTo`, `tags`, `state`. Custom and HTML fields go in `additionalFields: [{ path, value }]`,
  where `path` is the reference name.
- **`bulk-create-work-items`** - 1 to 20 items in one call with parent linking; best for an
  Epic-to-Task tree.

### Parent linking in bulk-create

Each item can carry `parent`:
- **Positive** = an existing work item ID.
- **Negative** = a **1-based index into this batch**: `-1` is the **first** item, `-2` the second, and
  so on. Not "the previous item". A parent must appear earlier in the list than its child.

```
items = [
  { type: "Epic",       title: "..." },                 // item 1
  { type: "Feature",    title: "...", parent: -1 },       // child of Epic
  { type: "User Story", title: "...", parent: -2 },       // child of Feature
  { type: "Task",       title: "...", parent: -3 },       // child of Story
  { type: "Bug",        title: "...", parent: -3 },       // Bug under the Story
]
```

Create separately and link later with `link-work-items` if a batch will not fit.

### What to set on each type

- **Epic**: title, description, area, iteration, **Priority** (required on Epic - pass `priority`).
- **Feature**: title, description, area, iteration.
- **User Story**: title; `Custom.UserStorydetail`; `Custom.DefinitionofReady`;
  `Microsoft.VSTS.Common.AcceptanceCriteria`; `originalEstimate`; and the three estimating picklists
  when the story is being estimated. (Value Area defaults to Business.) If `get-work-item-fields` returns
  NOT_FOUND for the project (currently DDP only), the connector cannot write these custom/HTML fields -
  scaffold via the connector and set them in the UI; see Section 2.
- **Task**: title, description, `originalEstimate` / `remainingWork`, parent Story.
- **Bug**: title, repro/description, parent **User Story**. Confirm Bug's required fields with the
  field reference for the process (see `references/custom-fields.md`).

---

## 5. Formatting conventions

Full detail and examples in `references/formatting.md`.

- **Titles**: short, descriptive, title case, no trailing full stop, 5 to 10 words, written from the
  user's point of view (for example `Submit a proposal for consideration`).
- **Acceptance criteria HTML** (written to the `Microsoft.VSTS.Common.AcceptanceCriteria` field): one
  `<p>` per scenario, scenario title in `<strong>`, each Given/When/Then/And on its own line with
  `<br>`, no extra spacing, a paragraph gap between scenarios, no `<h3>` or other markup:

  ```html
  <p><strong>Scenario: Submit a complete proposal</strong><br>Given a proposal has all mandatory fields completed<br>When the user submits it<br>Then the status is set to Submitted<br>And the submitter receives a confirmation</p>
  <p><strong>Scenario: Submit an incomplete proposal</strong><br>Given a mandatory field is missing<br>When the user submits it<br>Then submission is blocked<br>And the outstanding fields are identified</p>
  ```

- **Tags**: semicolon-separated. Reuse existing tags (requirement reference such as `BR.15.M`, plus a
  feature tag such as `Investment Pipeline`) rather than inventing near-duplicates.
- **Australian English** throughout. Do not use long dashes; use a short hyphen, a comma, or nothing.

---

## 6. Verify after creating

Create calls can partially succeed. After a batch:
1. Read the per-item `created` / `failed` / `skipped` status and capture the new IDs.
2. Read back a sample with `get-work-items-batch` (request the custom fields) to confirm `Custom.UserStorydetail`,
   `Custom.DefinitionofReady` and the acceptance criteria actually saved - not just that an ID returned.
3. Confirm parent/child links with `get-work-item-children` on the parent.
4. Report created IDs and a one-line summary; flag anything that came back failed, with the reason.

> `get-sprint-work-items` misses nested children; cross-check against the board or backlog when
> completeness matters. See `references/pitfalls.md`.

---

## 7. Reference files

- `references/custom-fields.md` - the shared custom fields, where each piece of content goes, allowed
  values, per-type required fields, the two processes, and how to discover fields (including the
  per-project connector quirk where `get-work-item-fields` currently fails on the DDP project).
- `references/writing-stories.md` - how to write the story statement and acceptance criteria well
  (roles, Given/When/Then keyword rules, scenario coverage, traceability).
- `references/formatting.md` - titles, the acceptance-criteria HTML format, tags, language.
- `references/pitfalls.md` - known process and connector issues with workarounds.
- `references/examples.md` - worked end-to-end examples on a Mojility project.

---

## 8. Safety

Creating, linking and updating work items is normal work and needs no confirmation. **Pause and confirm
before**: deleting or removing work items, bulk state changes across many items, changing area/iteration
structure, or editing a process (fields, types, rules). Processes are shared across projects, so changes
are wide-reaching and hard to undo.
