# Git Workflow in Neovim

## Browse modified files
- `<leader>gs` — fuzzy-find modified files with diff preview, opens file in normal buffer

## Navigate hunks
- `]h` / `[h` — jump to next/previous hunk
- `ih` — select current hunk (works with visual/operator mode, e.g. `vih`, `dih`)

## Inspect changes
- `<leader>ghp` — preview hunk in a popup
- `<leader>ghd` — open side-by-side diff view
- `<leader>ghq` — close diff view
- `<leader>ghb` — blame current line

## Stage & undo
- `<leader>ghs` — stage hunk
- `<leader>ghr` — reset hunk (undo change)
- `<leader>ghS` — stage entire buffer
- `<leader>ghR` — reset entire buffer

## Diff view
- Left pane = index (committed), right pane = working copy
