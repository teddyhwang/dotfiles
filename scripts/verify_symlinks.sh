#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

dotfiles_path=$(get_realpath "$(pwd)")

print_progress "Checking for broken symlinks pointing to dotfiles..."

# Function to check and handle broken symlink
check_broken_symlink() {
  link="$1"
  target=$(readlink "$link")
  case "$target" in
    "$dotfiles_path"*)
      if [ ! -e "$link" ]; then
        print_error "Found broken symlink: $link -> $target"
        printf "Do you want to remove it? (y/N) "
        read -r response </dev/tty
        printf "\033[1A\033[2K\033[1A"
        case "$response" in
          [Yy]|[Yy][Ee][Ss])
            print_progress "Removing broken symlink..."
            rm "$link"
            track_change
            ;;
          *)
            print_warning "Keeping broken symlink"
            ;;
        esac
      fi
      ;;
  esac
}

# Check home directory dotfiles
find "$HOME" -maxdepth 1 -name '.*' -type l 2>/dev/null | while IFS= read -r link; do
  check_broken_symlink "$link"
done

# Check config directories
for dir in "$HOME/.config" "$HOME/.bin" "$HOME/.local/bin" "$HOME/.config/hypr"; do
  if [ -d "$dir" ]; then
    find "$dir" -type l 2>/dev/null | while IFS= read -r link; do
      check_broken_symlink "$link"
    done
  fi
done

print_conditional_success "Symlink verification"
