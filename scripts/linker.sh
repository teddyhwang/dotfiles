#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

dotfiles_path=$(get_realpath "$(pwd)")

if [ -n "${CHECK_BROKEN_SYMLINKS}" ]; then
  print_progress "Checking for broken symlinks pointing to dotfiles..."

  find "$HOME" -maxdepth 1 -name '.*' -type l 2>/dev/null | while IFS= read -r link; do
    target=$(readlink "$link")
    case "$target" in
      "$dotfiles_path"*)
        if [ ! -e "$link" ]; then
          print_error "Found broken symlink: $link -> $target"
          print_progress "Removing broken symlink..."
          rm "$link"
          track_change
        fi
        ;;
    esac
  done

  for dir in "$HOME/.config" "$HOME/.bin" "$HOME/.config/hypr"; do
    if [ -d "$dir" ]; then
      find "$dir" -type l 2>/dev/null | while IFS= read -r link; do
        target=$(readlink "$link")
        case "$target" in
          "$dotfiles_path"*)
            if [ ! -e "$link" ]; then
              print_error "Found broken symlink: $link -> $target"
              print_progress "Removing broken symlink..."
              rm "$link"
              track_change
            fi
            ;;
        esac
      done
    fi
  done
fi

print_progress "Symlinking dotfiles..."

for filepath in home/.[!.]*; do
  file=$(basename "$filepath")
  source="$(pwd)/$filepath"
  target="$HOME/$file"

  validate_and_symlink "$source" "$target"
done

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
