#!/usr/bin/env bash
# Builds ~/dotfiles/yazi/keymap.toml from:
#   - ~/dotfiles/yazi/keymap.base.toml  (shared, tracked in git)
#   - ~/dotfiles/yazi/keymap.local.toml (machine-specific gotos, not tracked)
#
# keymap.local.toml should contain raw keymap array entries, e.g.:
#   { on = [ "g", "p" ], run = "cd ~/Projects", desc = "Jump to projects" },

BASE="$HOME/dotfiles/yazi/keymap.base.toml"
LOCAL="$HOME/dotfiles/yazi/keymap.local.toml"
OUTPUT="$HOME/dotfiles/yazi/keymap.toml"

if [ ! -f "$BASE" ]; then
    echo "build-keymap: base file not found: $BASE" >&2
    exit 1
fi

# Skip rebuild if output is newer than both source files
if [ -f "$OUTPUT" ] && [ "$OUTPUT" -nt "$BASE" ] && { [ ! -f "$LOCAL" ] || [ "$OUTPUT" -nt "$LOCAL" ]; }; then
    exit 0
fi

if [ -f "$LOCAL" ]; then
    awk -v localfile="$LOCAL" '
        /# \{\{MACHINE_GOTOS\}\}/ {
            while ((getline line < localfile) > 0) print line
            close(localfile)
            next
        }
        { print }
    ' "$BASE" > "$OUTPUT"
else
    # No local file — strip the placeholder comment and write base as-is
    grep -v '# {{MACHINE_GOTOS}}' "$BASE" > "$OUTPUT"
fi
