# Cursor dotfiles

Versioned Cursor config that lives outside `~/.cursor` runtime state.

## MCP

| File | Purpose |
|------|---------|
| `mojo-mcp.json` | **Active** global MCPs — symlinked to `~/.cursor/mcp.json` |
| `mcp-catalog.json` | Full library — copy entries into active or per-project config |

**Active by default (lean):** `azure-devops`, `ag-mcp`

**Catalog only (heavy / situational):** `Playwright`, `browser-tools`, `Figma`, `fireflies`

Cursor has no `enabled: false` in `mcp.json`. If a server is listed, it may spawn (per workspace toggle). Keep optional servers out of `mojo-mcp.json`.

### New machine

```bash
ln -sfn ~/dotfiles/cursor/mojo-mcp.json ~/.cursor/mcp.json
```

Restart Cursor or start a new agent session after changing MCP config.

### Enable a catalog server for one project

Add to that repo's `.cursor/mcp.json` (merge with global):

```json
{
  "mcpServers": {
    "Playwright": {
      "command": "npx @playwright/mcp@latest",
      "env": {}
    }
  }
}
```

Copy definitions from `mcp-catalog.json`. Project-level keys override global names.

### Temporarily enable globally

Copy the server block from `mcp-catalog.json` into `mojo-mcp.json`, symlink is already in place. Remove when done to avoid spawning it in every Herdr pane.

## Skills

See [skills/README.md](skills/README.md).
