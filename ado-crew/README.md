# ADO Crew

Skills for the ADO Crew workflow: manager, team-lead, interrogator, worker, reviewer, demonstrator, release notes, and the signal runtime.

`skills/` is the package. Cursor and Claude load each skill only when `<skills-dir>/<name>/SKILL.md` is a direct child of a skills directory, so this folder is not a skills root by itself.

## Install

```bash
./install.sh
```

Links every skill into `~/.cursor/skills` and `~/.claude/skills`. A path that is already a real directory is left alone.

In this dotfiles repo, `cursor/skills/ado-crew-*` and `claude/skills/ado-crew-*` are those links. `~/.claude/skills` points at `claude/skills`, so Claude follows them. Cursor links each skill from `~/.cursor/skills`.

## Layout

Keep the skill directories as siblings. `ado-crew-signal/scripts` finds `ado-crew-release-notes` by a relative path. Agents still run `~/.cursor/skills/ado-crew-signal/scripts/…`, which resolves through the install links.
