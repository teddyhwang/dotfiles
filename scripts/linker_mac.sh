#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

. "${SCRIPT_DIR}/linker.sh"

print_progress "\nSymlinking Hammerspoon config..."

validate_and_symlink "$DOTFILES_DIR/home/.hammerspoon" "$HOME/.hammerspoon"

print_progress "\nSymlinking binaries..."

for filepath in home/local/bin/*; do
  entry_name=$(basename "$filepath")
  src_path="$DOTFILES_DIR/$filepath"
  dst_path="$HOME/.local/bin/$entry_name"

  validate_and_symlink "$src_path" "$dst_path"
done

print_conditional_success "Symlinking"
