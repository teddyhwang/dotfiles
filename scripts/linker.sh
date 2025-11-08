#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Symlinking dotfiles..."

for filepath in home/.[!.]*; do
  file=$(basename "$filepath")
  source="$(pwd)/$filepath"
  target="$HOME/$file"

  validate_and_symlink "$source" "$target"
done

validate_and_symlink "$DOTFILES_DIR/home/shared" "$HOME/.shared"

print_progress "\nSymlinking config directories..."

for filepath in home/config/*; do
  file=$(basename "$filepath")
  source="$(pwd)/$filepath"
  target="$HOME/.config/$file"

  validate_and_symlink "$source" "$target"
done

print_progress "\nSymlinking binaries..."

for filepath in home/bin/*; do
  file=$(basename "$filepath")
  source="$(pwd)/$filepath"
  target="$HOME/.bin/$file"

  validate_and_symlink "$source" "$target"
done

print_conditional_success "Symlinks"
