#!/bin/bash
# Wait for Claude to finish its final response, then send /clear to the current tmux pane.
# Runs in the background — do not call this in the foreground.

sleep 3

if [ -n "$TMUX" ] && [ -n "$TMUX_PANE" ]; then
  tmux send-keys -t "$TMUX_PANE" "/clear" Enter
else
  # Not in tmux — nothing to do. The handover note is still in memory and
  # will surface when the user manually starts a new session.
  echo "Not in tmux. Start a new Claude Code session — your handover note will load automatically." >&2
fi
