#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Configuring git and bat..."

if [ -d ~/.cache/bat ]; then
  print_info "Bat cache already exists, skipping build."
else
  print_info "Building bat cache..."
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
