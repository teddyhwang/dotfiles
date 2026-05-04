#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Symlinking dotfiles..."

for filepath in home/.[!.]*; do
  entry_name=$(basename "$filepath")
  src_path="$DOTFILES_DIR/$filepath"
  dst_path="$HOME/$entry_name"

  # Skip mac-only dotfiles
  [ "$entry_name" = ".hammerspoon" ] && continue

  validate_and_symlink "$src_path" "$dst_path"
done

validate_and_symlink "$DOTFILES_DIR/home/shared" "$HOME/.shared"

print_progress "\nSymlinking config directories..."

for filepath in home/config/*; do
  entry_name=$(basename "$filepath")
  src_path="$DOTFILES_DIR/$filepath"
  dst_path="$HOME/.config/$entry_name"

  # Symlink individual files for configs that shouldn't have the whole dir tracked
  if [ "$entry_name" = "opencode" ] || [ "$entry_name" = "tmux" ] || [ "$entry_name" = "opensessions" ] || [ "$entry_name" = "zed" ]; then
    mkdir -p "$dst_path"
    for subfile in "$src_path"/*; do
      subfile_dst="$dst_path/$(basename "$subfile")"
      validate_and_symlink "$subfile" "$subfile_dst"
    done
    continue
  fi

  validate_and_symlink "$src_path" "$dst_path"
done

print_progress "\nSymlinking Claude config..."

mkdir -p "$HOME/.claude"
for filepath in home/claude/*; do
  entry_name=$(basename "$filepath")
  src_path="$DOTFILES_DIR/$filepath"
  dst_path="$HOME/.claude/$entry_name"

  validate_and_symlink "$src_path" "$dst_path"
done

print_progress "\nSymlinking pi agent config..."

mkdir -p "$HOME/.pi/agent"
for filepath in home/pi-agent/*; do
  entry_name=$(basename "$filepath")
  src_path="$DOTFILES_DIR/$filepath"
  dst_path="$HOME/.pi/agent/$entry_name"

  validate_and_symlink "$src_path" "$dst_path"
done
