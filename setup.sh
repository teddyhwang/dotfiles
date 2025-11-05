#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/utils.sh
source "${SCRIPT_DIR}/scripts/utils.sh"

# Check for required dependencies
print_status "Checking dependencies...\n"
missing_deps=()

for cmd in curl git readlink; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing_deps+=("$cmd")
  fi
done

if [ ${#missing_deps[@]} -gt 0 ]; then
  print_error "Missing required dependencies: ${missing_deps[*]}"
  print_error "Please install the following before running setup:"
  for dep in "${missing_deps[@]}"; do
    print_error "  - $dep"
  done
  exit 1
fi

print_success "All required dependencies found\n"

print_status "Starting installation...\n"

OS="$(uname -s)"

case "$OS" in
Darwin)
  print_progress "Installing Mac dependencies..."
  ./scripts/mac.sh
  ./scripts/omz.sh
  ./scripts/directories.sh
  ./scripts/linker.sh
  ./scripts/plugins.sh
  ./scripts/tmux.sh
  ./scripts/git-bat.sh
  ;;
Linux)
  print_progress "Installing Linux dependencies..."
  ./scripts/tmux.sh

  print_progress "Symlinking config directories..."

  # Folders to symlink for Linux
  linux_configs=(
    "atuin"
    "bat"
    "btop"
    "ghostty"
    "lazygit"
    "nvim"
    "tinted-theming"
    "yamllint"

    "yazi"
  )

  # Ensure .config exists
  mkdir -p "$HOME/.config"

  for config in "${linux_configs[@]}"; do
    filepath="$SCRIPT_DIR/home/config/$config"

    if [ ! -e "$filepath" ]; then
      print_warning "$config does not exist in dotfiles, skipping"
      continue
    fi

    source="$filepath"
    target="$HOME/.config/$config"

    validate_and_symlink "$config" "$source" "$target"
  done

  print_progress "Symlinking home directory dotfiles..."

  # Individual dotfiles to symlink for Linux
  linux_dotfiles=(
    ".ignore"
    ".gitignore"
    ".tmux.conf"
    ".shared.gitconfig"
    ".curlrc"
    ".myclirc"
    ".rgignore"
  )

  for dotfile in "${linux_dotfiles[@]}"; do
    filepath="$SCRIPT_DIR/home/$dotfile"

    if [ ! -e "$filepath" ]; then
      print_warning "$dotfile does not exist in dotfiles, skipping"
      continue
    fi

    source="$filepath"
    target="$HOME/$dotfile"

    validate_and_symlink "$dotfile" "$source" "$target"
  done

  print_conditional_success "Linux setup"
  ;;
*)
  print_error "Unsupported operating system: $OS"
  exit 1
  ;;
esac

print_success "Local setup complete 🚀"
