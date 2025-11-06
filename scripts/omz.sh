#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"

print_progress "Installing OhMyZSH..."

if ! [ -d ~/.oh-my-zsh ]; then
  print_progress "Installing OhMyZsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  print_info "Oh My ZSH is installed"
fi

print_conditional_success "OhMyZsh"
