#!/bin/zsh

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/print.sh"

if ! [ -d ~/.tmux ]; then
  print_progress "Installing tmux plugin manager..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
  print_info "tmux plugin manager is installed"
fi

if [ ! -d ~/.tmux/plugins/base16-tmux-powerline ]; then
  print_progress "Installing tmux plugins..."
  tmux new-session -d "sleep 1"
  sleep 0.1
  ~/.tmux/plugins/tpm/bin/install_plugins
else
  print_info "tmux plugins installed"
fi

print_success "tmux setup complete 🎉"
