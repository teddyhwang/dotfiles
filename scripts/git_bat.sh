#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Configuring git and bat..."

if bat --list-themes | grep -Fqx 'base16-256'; then
  print_info "Bat's configured theme is available"
else
  print_error "Bat theme base16-256 is unavailable"
  exit 1
fi

shared_gitconfig="$HOME/.shared.gitconfig"
if git config --global --get-all include.path 2>/dev/null | grep -Fqx "$shared_gitconfig"; then
  print_info "include.path already contains $shared_gitconfig"
else
  print_progress "Adding shared git config include.path..."
  git config --global --add include.path "$shared_gitconfig"
  track_change
fi

if ! git config --get commit.gpgsign >/dev/null 2>&1; then
  print_info "Git signing is opt-in per machine; provision a key before enabling commit.gpgsign (see README.md)."
fi

if ! git var GIT_AUTHOR_IDENT >/dev/null 2>&1; then
  print_warning "Git identity is not configured. Before committing, set user.name and user.email (see README.md)."
fi

print_conditional_success "git and bat"
