#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Symlinking dotfiles..."

for filepath in "$DOTFILES_DIR"/home/.[!.]*; do
  [ -e "$filepath" ] || [ -L "$filepath" ] || continue
  entry_name=$(basename -- "$filepath")
  dst_path="$HOME/$entry_name"

  # Skip mac-only dotfiles.
  [ "$entry_name" = ".hammerspoon" ] && continue

  validate_and_symlink "$filepath" "$dst_path"
done

validate_and_symlink "$DOTFILES_DIR/home/shared" "$HOME/.shared"

print_progress "\nSymlinking config directories..."

for filepath in "$DOTFILES_DIR"/home/config/*; do
  [ -e "$filepath" ] || [ -L "$filepath" ] || continue
  entry_name=$(basename -- "$filepath")
  dst_path="$HOME/.config/$entry_name"

  # Symlink individual files for configs that shouldn't have the whole dir tracked.
  case "$entry_name" in
    opencode | tmux | opensessions | zed | herdr)
      mkdir -p "$dst_path"
      for subfile in "$filepath"/*; do
        [ -e "$subfile" ] || [ -L "$subfile" ] || continue
        subfile_dst="$dst_path/$(basename -- "$subfile")"
        validate_and_symlink "$subfile" "$subfile_dst"
      done
      continue
      ;;
  esac

  validate_and_symlink "$filepath" "$dst_path"
done

print_progress "\nSymlinking Claude config..."

mkdir -p "$HOME/.claude"
for filepath in "$DOTFILES_DIR"/home/claude/*; do
  [ -e "$filepath" ] || [ -L "$filepath" ] || continue
  entry_name=$(basename -- "$filepath")
  dst_path="$HOME/.claude/$entry_name"

  validate_and_symlink "$filepath" "$dst_path"
done

print_progress "\nSymlinking pi agent config..."

mkdir -p "$HOME/.pi/agent"
for filepath in "$DOTFILES_DIR"/home/pi-agent/*; do
  [ -e "$filepath" ] || [ -L "$filepath" ] || continue
  entry_name=$(basename -- "$filepath")
  dst_path="$HOME/.pi/agent/$entry_name"

  # Herdr and pi packages install their own extensions into this directory.
  # Link our entries individually so setup never replaces those managed files.
  if [ "$entry_name" = "extensions" ]; then
    mkdir -p "$dst_path"
    for extension in "$filepath"/*; do
      [ -e "$extension" ] || [ -L "$extension" ] || continue
      validate_and_symlink "$extension" "$dst_path/$(basename -- "$extension")"
    done
    continue
  fi

  validate_and_symlink "$filepath" "$dst_path"
done
