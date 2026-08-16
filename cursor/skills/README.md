# Cursor skills (source)

Real files live here. Other paths are links:

- `~/.cursor/skills/ado-crew-*` → these directories
- `claude/skills/ado-crew-*` → these directories (so `~/.claude/skills` sees them)

Do not put GSD / plugin skills here — those stay in `~/.cursor/skills` as local installs.

On a new machine, after cloning dotfiles:

```bash
mkdir -p ~/.cursor/skills
for s in ado-crew-manager ado-crew-reviewer ado-crew-signal ado-crew-team-lead ado-crew-worker; do
  ln -sfn ../../dotfiles/cursor/skills/$s ~/.cursor/skills/$s
done
```

Claude is already covered if `~/.claude/skills` → `~/dotfiles/claude/skills`.
