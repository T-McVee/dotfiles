# Cursor skills (source)

Global MCP config: see [../README.md](../README.md).

Real files live here. Other paths are links:

- `~/.cursor/skills/ado-crew-*` → these directories
- `claude/skills/ado-crew-*` → these directories (so `~/.claude/skills` sees them)

Do not put GSD / plugin skills here — those stay in `~/.cursor/skills` as local installs.

Default Cursor models per persona: `ado-crew-signal/models.json`. Spawn via `ado-crew-signal/scripts/spawn-agent.sh` so `--model` is applied.

On a new machine, after cloning dotfiles:

```bash
mkdir -p ~/.cursor/skills
for s in ado-crew-manager ado-crew-reviewer ado-crew-signal ado-crew-team-lead ado-crew-worker ado-crew-demonstrator; do
  ln -sfn ../../dotfiles/cursor/skills/$s ~/.cursor/skills/$s
done
```

Claude is already covered if `~/.claude/skills` → `~/dotfiles/claude/skills`.
