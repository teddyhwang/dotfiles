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
# Personal Pi extensions now live in the installed teddyhwang/pi-extensions
# package. Retire only our exact legacy symlink; never remove another installer's
# files or a user-maintained copy.
legacy_pi_extension="$HOME/.pi/agent/extensions/session-tab-name.ts"
canonical_pi_extension="$HOME/.pi/agent/git/github.com/teddyhwang/pi-extensions/extensions/session-tab-name/index.ts"
if [ -L "$legacy_pi_extension" ] && \
  [ "$(readlink "$legacy_pi_extension")" = "$DOTFILES_DIR/home/pi-agent/extensions/session-tab-name.ts" ]; then
  if [ -f "$canonical_pi_extension" ]; then
    rm -- "$legacy_pi_extension"
  else
    print_warning "Install teddyhwang/pi-extensions before retiring the legacy session-tab-name symlink"
  fi
fi

for filepath in "$DOTFILES_DIR"/home/pi-agent/*; do
  [ -e "$filepath" ] || [ -L "$filepath" ] || continue
  entry_name=$(basename -- "$filepath")
  dst_path="$HOME/.pi/agent/$entry_name"

  # Extension implementation belongs in the canonical Pi package, not dotfiles.
  if [ "$entry_name" = "extensions" ]; then
    print_error "Pi extensions must live in https://github.com/teddyhwang/pi-extensions"
    exit 1
  fi

  # Link only our definitions, preserving other user/installer-owned roles.
  if [ "$entry_name" = "agents" ]; then
    mkdir -p "$dst_path"
    for definition in "$filepath"/*.md; do
      [ -f "$definition" ] || continue
      validate_and_symlink "$definition" "$dst_path/$(basename -- "$definition")"
    done
    continue
  fi

  validate_and_symlink "$filepath" "$dst_path"
done
