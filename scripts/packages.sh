#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"

print_progress "Installing custom packages..."

packages=(
  "atuin"
  "bash-preexec"
  "carapace-bin"
  "claude-code"
  "git-delta"
  "google-chrome"
  "keychain"
  "keyd"
  "lsof"
  "rust"
  "seahorse"
  "tig"
  "tmux"
  "ttf-firacode-nerd"
  "ttf-meslo-nerd"
  "yazi"
  "zellij"
  "zsh"
)

packages_to_install=()

for package in "${packages[@]}"; do
  if pacman -Q "$package" &> /dev/null; then
    print_info "$package is already installed"
  else
    print_progress "$package needs to be installed"
    packages_to_install+=("$package")
    track_change
  fi
done

if [ ${#packages_to_install[@]} -gt 0 ]; then
  print_progress "Installing ${#packages_to_install[@]} package(s)..."
  yay -S --needed --noconfirm "${packages_to_install[@]}"
else
  print_info "All packages are already installed"
fi

print_conditional_success "Custom packages"
