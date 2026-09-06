#!/bin/sh

# Portable realpath for sh compatibility.
get_realpath() {
  path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$path"
  elif [ -L "$path" ]; then
    link_target=$(readlink "$path")
    case "$link_target" in
      /*) get_realpath "$link_target" ;;
      *) get_realpath "$(dirname -- "$path")/$link_target" ;;
    esac
  elif [ -d "$path" ]; then
    (CDPATH='' cd -- "$path" && pwd -P)
  else
    directory=$(dirname -- "$path")
    filename=$(basename -- "$path")
    (CDPATH='' cd -- "$directory" && printf '%s/%s\n' "$(pwd -P)" "$filename")
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

confirm() {
  prompt="$1"
  response=""
  printf "%s (y/N) " "$prompt"
  if IFS= read -r response </dev/tty 2>/dev/null; then
    printf "\033[1A\033[2K"
  else
    IFS= read -r response 2>/dev/null || response=""
    printf "\n"
  fi
  case "$response" in
    [Yy] | [Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

# Validate both the spelling and the physical parent before creating anything.
# Resolving the leaf itself would follow the very symlink we intend to replace.
validate_home_target() (
  candidate=$1
  case "${HOME:-}" in
    / | '') print_error "Refusing to manage an empty or root HOME"; exit 1 ;;
    /*) ;;
    *) print_error "HOME must be an absolute path"; exit 1 ;;
  esac
  case "$candidate" in
    "$HOME"/*) ;;
    *) print_error "Refusing to manage a symlink outside HOME: $candidate"; exit 1 ;;
  esac
  case "$candidate/" in
    */../* | */./* | *//*)
      print_error "Refusing an ambiguous target path: $candidate"; exit 1 ;;
  esac
  case "$candidate" in
    */) print_error "Refusing a target with a trailing slash: $candidate"; exit 1 ;;
  esac

  home_real=$(CDPATH='' cd -- "$HOME" && pwd -P) || exit 1
  [ "$home_real" != / ] || { print_error "Refusing HOME resolving to root"; exit 1; }
  parent=$(dirname -- "$candidate")
  while [ ! -e "$parent" ] && [ ! -L "$parent" ]; do
    parent=$(dirname -- "$parent")
  done
  parent_real=$(CDPATH='' cd -- "$parent" && pwd -P) || exit 1
  case "$parent_real" in
    "$home_real" | "$home_real"/*) ;;
    *) print_error "Refusing a target whose parent escapes HOME: $candidate"; exit 1 ;;
  esac
)

# Symlink utilities: never overwrite a path that appeared after validation.
symlink() {
  ln -s -- "$1" "$2"
}

validate_and_symlink() {
  source="$1"
  target="$2"
  file=$(basename -- "$source")

  if [ "$file" = ".DS_Store" ]; then
    print_info "Ignoring system file."
    return 0
  fi

  if [ ! -e "$source" ] && [ ! -L "$source" ]; then
    print_error "Cannot symlink missing source: $source"
    return 1
  fi

  validate_home_target "$target" || return 1
  mkdir -p -- "$(dirname -- "$target")" || return 1

  if [ -L "$target" ] && [ "$(get_realpath "$target")" = "$(get_realpath "$source")" ]; then
    print_info "$target is symlinked to your dotfiles."
  elif [ -e "$target" ] || [ -L "$target" ]; then
    print_warning "$target exists and differs from your dotfile."
    if confirm "Do you want to replace it?"; then
      backup_root="$HOME/.local/state/dotfiles/backups"
      validate_home_target "$backup_root/entry" || return 1
      mkdir -p -- "$backup_root" || return 1
      backup_dir=$(mktemp -d "$backup_root/replaced.XXXXXX") || return 1
      backup="$backup_dir/$(basename -- "$target")"
      mv -- "$target" "$backup" || return 1
      if ! symlink "$source" "$target"; then
        print_error "Could not create $target; original preserved at $backup"
        if [ ! -e "$target" ] && [ ! -L "$target" ]; then
          mv -- "$backup" "$target" || true
        fi
        return 1
      fi
      print_info "Preserved original at $backup"
      track_change
    else
      print_info "Keeping existing $target"
    fi
  else
    print_progress "$target does not exist. Symlinking to dotfile."
    symlink "$source" "$target" || return 1
    track_change
  fi
}
