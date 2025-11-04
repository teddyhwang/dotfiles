#!/usr/bin/env bash

# Portable realpath for bash 3.2 compatibility
get_realpath() {
  local path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$path"
  else
    ( cd "$(dirname "$path")" && pwd -P )
  fi
}

export C_DEFAULT="\x1B[39m"
export C_GREEN="\x1B[32m"
export C_RED="\x1B[31m"
export C_LIGHTGRAY="\x1B[90m"
export C_ORANGE="\x1B[33m"
export C_BLUE="\x1B[34m"
export C_CYAN="\x1B[36m"

print_success() {
  echo -e "${C_GREEN}$1${C_DEFAULT}"
}

print_error() {
  echo -e "${C_RED}$1${C_DEFAULT}"
}

print_warning() {
  echo -e "${C_ORANGE}$1${C_DEFAULT}"
}

print_info() {
  echo -e "${C_LIGHTGRAY}$1${C_DEFAULT}"
}

print_status() {
  echo -e "${C_BLUE}$1${C_DEFAULT}"
}

print_progress() {
  echo -e "${C_CYAN}$1${C_DEFAULT}"
}

changes_made=0

track_change() {
  changes_made=1
}

reset_changes() {
  changes_made=0
}

print_conditional_success() {
  local component="${1:-Component}"
  if [ "$changes_made" -eq 1 ]; then
    print_success "$component setup complete 🎉\n"
  else
    print_status "$component already configured, no changes needed\n"
  fi
  reset_changes
}

# Symlink utilities
symlink() {
  ln -nsf "$1" "$2"
}

validate_and_symlink() {
  local file="$1"
  local source="$2"
  local target="$3"

  if [ "$file" = ".DS_Store" ]; then
    print_info "Ignoring system file."
  elif [[ -h "$target" && "$(readlink "$target")" == "$source" ]]; then
    print_info "$target is symlinked to your dotfiles."
  elif [[ -e "$target" ]]; then
    print_warning "$target exists and differs from your dotfile."
    read -r -p "Do you want to replace it? (y/N) " response
    echo -e "\033[1A\033[2K\033[1A"
    if [[ "$response" =~ ^[Yy]$ ]]; then
      print_progress "Replacing existing file..."
      rm -rf "$target" && symlink "$source" "$target"
      track_change
    else
      print_warning "Keeping existing file"
    fi
  else
    print_progress "$target does not exist. Symlinking to dotfile."
    symlink "$source" "$target"
    track_change
  fi
}
