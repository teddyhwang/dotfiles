#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"

print_progress "Installing tmux plugins..."

if ! [ -d ~/.tmux ]; then
  print_progress "Installing tmux plugin manager..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  track_change
else
  print_info "tmux plugin manager is installed"
fi

if [ ! -d ~/.tmux/plugins/base16-tmux-powerline ]; then
  print_progress "Installing tmux plugins..."
  tmux new-session -d "sleep 1"
  sleep 0.1
  ~/.tmux/plugins/tpm/bin/install_plugins
  track_change
else
  print_info "tmux plugins installed"
fi

print_conditional_success "tmux"
