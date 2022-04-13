#!/bin/zsh

if [ ! -d ~/.tmux/plugins/base16-tmux-powerline ]; then
  tmux new-session -d "sleep 1"
  sleep 0.1
  ~/.tmux/plugins/tpm/bin/install_plugins
fi
