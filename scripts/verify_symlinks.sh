#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Checking for broken symlinks pointing to dotfiles..."

check_broken_symlink() {
  link="$1"
  target=$(readlink "$link")
  case "$target" in
    "$DOTFILES_DIR"*)
      if [ ! -e "$link" ]; then
        print_error "Found broken symlink: $link -> $target"
        if confirm "Do you want to remove it?"; then
          print_progress "Removing broken symlink..."
          rm -- "$link"
          track_change
        else
          print_warning "Keeping broken symlink"
        fi
      fi
      ;;
  esac
}

links_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-links.XXXXXX")
trap 'rm -f "$links_file"' 0 HUP INT TERM

find "$HOME" -maxdepth 1 -name '.*' -type l -print 2>/dev/null >"$links_file"
for directory in \
  "$HOME/.config" \
  "$HOME/.local/bin" \
  "$HOME/.pi/agent" \
  "$HOME/.claude"; do
  if [ -d "$directory" ]; then
    find "$directory" -type l -print 2>/dev/null >>"$links_file"
  fi
done

while IFS= read -r link; do
  check_broken_symlink "$link"
done <"$links_file"

rm -f "$links_file"
trap - 0 HUP INT TERM

print_conditional_success "Symlink verification"
