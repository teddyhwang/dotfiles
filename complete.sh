#!/bin/zsh

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/print.sh"

if ! [ -d ~/.cache/bat ]; then
  bat cache --build
fi

if git config --get-all include.path | grep -q .shared.gitconfig; then
  print_info "include.path already set with ~/.shared.gitconfig"
else
  print_success "Adding shared git config include.path..."
  git config --global include.path ~/.shared.gitconfig
fi

print_success "Installation complete 🎉"
