#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Installing custom packages..."

packages="atuin bash-preexec carapace-bin claude-code git-delta google-chrome keychain keyd lsof rust seahorse tig tmux ttf-firacode-nerd ttf-meslo-nerd yazi zellij zsh"

packages_to_install=""
package_count=0

for package in $packages; do
  if pacman -Q "$package" >/dev/null 2>&1; then
    print_info "$package is already installed"
  else
    print_progress "$package needs to be installed"
    packages_to_install="$packages_to_install $package"
    package_count=$((package_count + 1))
    track_change
  fi
done

if [ -n "$packages_to_install" ]; then
  print_progress "Installing $package_count package(s)..."
  # shellcheck disable=SC2086
  yay -S --needed --noconfirm $packages_to_install

  # Rebuild font cache if font packages were installed
  if echo "$packages_to_install" | grep -q "ttf-"; then
    print_progress "Rebuilding font cache..."
    fc-cache -fv >/dev/null 2>&1
    print_success "Font cache rebuilt"
  fi
else
  print_info "All packages are already installed"
fi

print_conditional_success "Custom packages"
