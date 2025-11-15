#!/bin/sh

# Portable realpath for sh compatibility
get_realpath() {
  path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$path"
  else
    ( cd "$(dirname "$path")" && pwd -P )
  fi
}

C_DEFAULT="\033[39m"
C_GREEN="\033[32m"
C_RED="\033[31m"
C_LIGHTGRAY="\033[90m"
C_ORANGE="\033[33m"
C_BLUE="\033[34m"
C_CYAN="\033[36m"

export C_DEFAULT C_GREEN C_RED C_LIGHTGRAY C_ORANGE C_BLUE C_CYAN

print_success() {
  printf "%b%b%b\n" "${C_GREEN}" "$1" "${C_DEFAULT}"
}

print_error() {
  printf "%b%b%b\n" "${C_RED}" "$1" "${C_DEFAULT}"
}

print_warning() {
  printf "%b%b%b\n" "${C_ORANGE}" "$1" "${C_DEFAULT}"
}

print_info() {
  printf "%b%b%b\n" "${C_LIGHTGRAY}" "$1" "${C_DEFAULT}"
}

print_status() {
  printf "%b%b%b\n" "${C_BLUE}" "$1" "${C_DEFAULT}"
}

print_progress() {
  printf "%b%b%b\n" "${C_CYAN}" "$1" "${C_DEFAULT}"
}

print_line() {
  printf "%b%s%b\n" "${C_LIGHTGRAY}" "-------------------------------------------------------------------------------" "${C_DEFAULT}"
}

changes_made=0

track_change() {
  changes_made=1
}

reset_changes() {
  changes_made=0
}

print_conditional_success() {
  component="${1:-Component}"
  if [ "$changes_made" -eq 1 ]; then
    printf "%b%s setup complete 🎉%b\n" "${C_GREEN}" "$component" "${C_DEFAULT}"
  else
    printf "%b%s already configured, no changes needed%b\n" "${C_BLUE}" "$component" "${C_DEFAULT}"
  fi
  print_line
  reset_changes
}

# Symlink utilities
symlink() {
  ln -nsf "$1" "$2"
}

validate_and_symlink() {
  source="$1"
  target="$2"
  file=$(basename "$source")

  if [ "$file" = ".DS_Store" ]; then
    print_info "Ignoring system file."
  elif [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    print_info "$target is symlinked to your dotfiles."
  elif [ -e "$target" ]; then
    print_warning "$target exists and differs from your dotfile."
    printf "Do you want to replace it? (y/N) "
    read -r response
    printf "\033[1A\033[2K"
    case "$response" in
      [Yy]|[Yy][Ee][Ss])
        print_progress "Replacing existing file..."
        rm -rf "$target" && symlink "$source" "$target"
        track_change
        ;;
      *)
        print_info "Keeping existing $target"
        ;;
    esac
  else
    print_progress "$target does not exist. Symlinking to dotfile."
    symlink "$source" "$target"
    track_change
  fi
}
