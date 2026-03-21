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

  # Skip mac-only dotfiles
  [ "$file" = ".hammerspoon" ] && continue

  validate_and_symlink "$source" "$target"
done

validate_and_symlink "$DOTFILES_DIR/home/shared" "$HOME/.shared"

print_progress "\nSymlinking config directories..."

for filepath in home/config/*; do
  file=$(basename "$filepath")
  source="$(pwd)/$filepath"
  target="$HOME/.config/$file"

  # Symlink individual files for configs that shouldn't have the whole dir tracked
  if [ "$file" = "opencode" ] || [ "$file" = "tmux" ]; then
    mkdir -p "$target"
    for subfile in "$source"/*; do
      validate_and_symlink "$subfile" "$target/$(basename "$subfile")"
    done
    continue
  fi

  validate_and_symlink "$source" "$target"
done

print_progress "\nSymlinking Claude config..."

mkdir -p "$HOME/.claude"
for filepath in home/claude/*; do
  file=$(basename "$filepath")
  source="$(pwd)/$filepath"
  target="$HOME/.claude/$file"

  validate_and_symlink "$source" "$target"
done

print_progress "\nSymlinking pi agent config..."

mkdir -p "$HOME/.pi/agent"
for filepath in home/pi-agent/*; do
  file=$(basename "$filepath")
  source="$(pwd)/$filepath"
  target="$HOME/.pi/agent/$file"

  validate_and_symlink "$source" "$target"
done
