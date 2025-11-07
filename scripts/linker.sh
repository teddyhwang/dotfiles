#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"

dotfiles_path=$(get_realpath "$(pwd)")

if [[ -n "${CHECK_BROKEN_SYMLINKS}" ]]; then
  print_progress "Checking for broken symlinks pointing to dotfiles..."

  find "$HOME" -maxdepth 1 -name '.*' -type l -print0 2>/dev/null | while IFS= read -r -d '' link; do
    target=$(readlink "$link")
    if [[ "$target" == "$dotfiles_path"* ]]; then
      if [[ ! -e "$link" ]]; then
        print_error "Found broken symlink: $link -> $target"
        print_progress "Removing broken symlink..."
        rm "$link"
        track_change
      fi
    fi
  done

  for dir in "$HOME/.config" "$HOME/.bin" "$HOME/.config/hypr"; do
    if [ -d "$dir" ]; then
      find "$dir" -type l -print0 2>/dev/null | while IFS= read -r -d '' link; do
        target=$(readlink "$link")
        if [[ "$target" == "$dotfiles_path"* ]]; then
          if [[ ! -e "$link" ]]; then
            print_error "Found broken symlink: $link -> $target"
            print_progress "Removing broken symlink..."
            rm "$link"
            track_change
          fi
        fi
      done
    fi
  done
fi

print_progress "\nSymlinking dotfiles..."

for filepath in home/.[^.]*; do
  file=$(basename "$filepath")
  source="$(pwd)/$filepath"
  target="$HOME/$file"

  validate_and_symlink "$file" "$source" "$target"
done

print_progress "\nSymlinking config directories..."

for filepath in home/config/*; do
  file=$(basename "$filepath")
  source="$(pwd)/$filepath"
  target="$HOME/.config/$file"

  validate_and_symlink "$file" "$source" "$target"
done

print_progress "\nSymlinking binaries..."

for filepath in home/bin/*; do
  file=$(basename "$filepath")
  source="$(pwd)/$filepath"
  target="$HOME/.bin/$file"

  validate_and_symlink "$file" "$source" "$target"
done

print_conditional_success "Symlinks"
