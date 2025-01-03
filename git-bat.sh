#!/bin/zsh

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/print.sh"

if ! [ -d ~/.cache/bat ]; then
  bat cache --build
  track_change
fi

if git config --get-all include.path | grep -q .shared.gitconfig; then
  print_info "include.path already set with ~/.shared.gitconfig"
else
  print_progress "Adding shared git config include.path..."
  git config --global include.path ~/.shared.gitconfig
  track_change
fi

print_conditional_success "git and bat"
