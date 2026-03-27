#!/bin/bash

# Shared tmux layout: nvim (left), claude (top-right), terminal (bottom-right)
# Usage: setup_dev_layout <tmux-target> <working-dir>
#   tmux-target: session:window (e.g. "mysession:repo")
#   working-dir: absolute path to start all panes in

setup_dev_layout() {
  local target="$1"
  local working_dir="$2"

  # Split window: right sidebar (30% width)
  tmux split-window -t "$target" -h -l 30% -c "$working_dir"

  # Split the right pane vertically into two stacked panes
  tmux split-window -t "$target.2" -v -l 20% -c "$working_dir"

  # Launch nvim in the primary left pane
  tmux send-keys -t "$target.1" 'nvim .' Enter

  # Launch Claude Code in the top-right sidebar pane
  tmux send-keys -t "$target.2" 'claude' Enter

  # Focus the primary left pane
  tmux select-pane -t "$target.1"
}
