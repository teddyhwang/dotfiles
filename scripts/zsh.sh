#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Setting up Zsh..."

ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [ -d "$ZINIT_HOME" ]; then
  print_info "zinit is installed"
else
  print_progress "Installing zinit..."
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
  track_change
fi

if [ -d ~/.zsh/completions ]; then
  print_info "Custom completions added"
else
  print_progress "Adding custom completions..."
  mkdir -p ~/.zsh/completions
  cp ./home/completions/* ~/.zsh/completions/.
  track_change
fi

print_conditional_success "Zsh"
