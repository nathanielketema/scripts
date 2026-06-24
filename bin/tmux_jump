#!/usr/bin/env bash

while true; do
  sessions=$(tmux list-sessions -F "#{session_name}")
  [ -z "$sessions" ] && echo "No tmux sessions available." && exit 0

  selected=$(echo "$sessions" | fzf \
    --prompt="Select tmux session: " \
    --preview='tmux list-windows -t {} \; list-panes -t {} -F "Window: #{window_name} | Pane: #{pane_title} | Cmd: #{pane_current_command}"' \
    --preview-window=down:60%:wrap \
    --height=40% \
    --reverse \
    --no-unicode \
    --bind "ctrl-d:execute-silent(tmux kill-session -t {})+reload(tmux list-sessions -F '#{session_name}')" \
    --header="[Enter] switch  [Ctrl+D] kill session")

  # Exit if nothing selected
  [[ -z "$selected" ]] && break

  # Switch to session if it still exists
  if tmux has-session -t "$selected" 2>/dev/null; then
    tmux switch-client -t "$selected"
    break
  fi
done
