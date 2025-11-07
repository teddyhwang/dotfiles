#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"

print_progress "\nSymlinking config directories..."

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

  validate_and_symlink "$source" "$target"
done

print_progress "\nSymlinking home directory dotfiles..."

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

  validate_and_symlink "$source" "$target"
done

print_progress "\nSymlinking hypr config..."

for filepath in home/hypr/*; do
  file=$(basename "$filepath")
  source="$(pwd)/$filepath"
  target="$HOME/.config/hypr/$file"

  validate_and_symlink "$source" "$target"
done

print_progress "\nSymlinking binaries..."

for filepath in home/local/bin/*; do
  file=$(basename "$filepath")
  source="$(pwd)/$filepath"
  target="$HOME/.local/bin/$file"

  validate_and_symlink "$source" "$target"
done

print_progress "\nSymlinking keyd config..."

validate_and_symlink "$DOTFILES_DIR/home/keyd/app.conf" "$HOME/.config/keyd/app.conf"
if [[ ! -f /etc/keyd/default.conf ]]; then
  cp "$DOTFILES_DIR/home/keyd/default.conf" "/etc/keyd/default.conf"
fi

print_conditional_success "Symlinking"
