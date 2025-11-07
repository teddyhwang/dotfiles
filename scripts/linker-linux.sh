#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"

print_progress "Symlinking config directories..."

configs=(
  "atuin"
  "bat"
  "btop"
  "lazygit"
  "nvim"
  "starship.toml"
  "tinted-theming"
  "yamllint"
  "yazi"
)

for config in "${configs[@]}"; do
  filepath="$DOTFILES_DIR/home/config/$config"

  if [ ! -e "$filepath" ]; then
    print_warning "$config does not exist in dotfiles, skipping"
    continue
  fi

  source="$filepath"
  target="$HOME/.config/$config"

  validate_and_symlink "$config" "$source" "$target"
done

print_progress "Symlinking home directory dotfiles..."

dotfiles=(
  ".bashrc"
  ".blerc"
  ".curlrc"
  ".functions.bash"
  ".gitignore"
  ".ignore"
  ".myclirc"
  ".rgignore"
  ".shared.gitconfig"
  ".tmux.conf"
)

for dotfile in "${dotfiles[@]}"; do
  filepath="$DOTFILES_DIR/home/$dotfile"

  if [ ! -e "$filepath" ]; then
    print_warning "$dotfile does not exist in dotfiles, skipping"
    continue
  fi

  source="$filepath"
  target="$HOME/$dotfile"

  validate_and_symlink "$dotfile" "$source" "$target"
done

print_conditional_success "Linux setup"

