#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Setting up Zsh..."

ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [ -d "$ZINIT_HOME" ]; then
  print_info "zinit is installed"
else
  print_progress "Installing zinit..."
  mkdir -p "$(dirname -- "$ZINIT_HOME")"
  git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
  track_change
fi

mkdir -p "$HOME/.zsh/completions"
for completion in "$DOTFILES_DIR"/home/completions/*; do
  [ -f "$completion" ] || continue
  destination="$HOME/.zsh/completions/$(basename -- "$completion")"
  if ! cmp -s "$completion" "$destination"; then
    print_progress "Installing $(basename -- "$completion")..."
    cp "$completion" "$destination"
    track_change
  fi
done

print_conditional_success "Zsh"
