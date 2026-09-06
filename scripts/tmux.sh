#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Installing tmux plugins..."

if ! [ -d ~/.config/tmux/plugins/tpm ]; then
  print_progress "Installing tmux plugin manager..."
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
  track_change
else
  print_info "tmux plugin manager is installed"
fi

if [ ! -d ~/.config/tmux/plugins/base16-tmux-powerline ]; then
  print_progress "Installing tmux plugins..."
  tmux new-session -d "sleep 1"
  sleep 0.1
  "$HOME/.config/tmux/plugins/tpm/bin/install_plugins"
  track_change
else
  print_info "tmux plugins installed"
fi

print_conditional_success "tmux"
