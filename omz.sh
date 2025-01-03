#!/bin/zsh

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/print.sh"

print_progress "Starting installation..."

if ! [ -d ~/.oh-my-zsh ]; then
  print_progress "Installing Oh My ZSH..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  print_info "Oh My ZSH is installed"
fi

print_success "Oh My ZSH installation complete 🎉"
