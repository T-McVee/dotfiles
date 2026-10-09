#!/usr/bin/env bash
# Link each ado-crew skill into the local Cursor and Claude skill directories.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/skills"
CURSOR_SKILLS="${CURSOR_SKILLS:-$HOME/.cursor/skills}"
CLAUDE_SKILLS="${CLAUDE_SKILLS:-$HOME/.claude/skills}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required to build relative symlink targets" >&2
  exit 1
fi

relpath() {
  python3 -c 'import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$1" "$2"
}

link_one() {
  local name="$1"
  local dest_root="$2"
  local target dest dest_physical rel current

  target="$SRC/$name"
  mkdir -p "$dest_root"
  dest="$dest_root/$name"
  dest_physical="$(cd "$dest_root" && pwd -P)"
  rel="$(relpath "$target" "$dest_physical")"

  if [[ -e "$dest" && ! -L "$dest" ]]; then
    echo "skip $dest (real directory)" >&2
    return 0
  fi

  if [[ -L "$dest" ]]; then
    current="$(readlink "$dest")"
    if [[ "$current" == "$rel" ]]; then
      echo "ok $dest -> $rel"
      return 0
    fi
  fi

  ln -sfn "$rel" "$dest"
  echo "linked $dest -> $rel"
}

shopt -s nullglob
found=0
for dir in "$SRC"/*/; do
  found=1
  name="$(basename "$dir")"
  link_one "$name" "$CURSOR_SKILLS"
  link_one "$name" "$CLAUDE_SKILLS"
done

if [[ "$found" -eq 0 ]]; then
  echo "ERROR: no skills under $SRC" >&2
  exit 1
fi
