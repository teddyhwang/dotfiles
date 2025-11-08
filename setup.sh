#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/utils.sh
. "${SCRIPT_DIR}/scripts/utils.sh"

print_line
./scripts/verify_dependencies.sh
print_line
OS="$(uname -s)"
case "$OS" in
Darwin)
  print_progress "Installing Mac dependencies..."
  ./scripts/packages-mac.sh
  ./scripts/verify_symlinks.sh
  ./scripts/directories.sh
  ./scripts/linker.sh
  ./scripts/zsh.sh
  ./scripts/tmux.sh
  ./scripts/git-bat.sh
  ;;
Linux)
  print_progress "Installing Linux dependencies..."
  ./scripts/verify_symlinks.sh
  ./scripts/linker-linux.sh
  ./scripts/tmux.sh
  ./scripts/packages-linux.sh
  ;;
*)
  print_error "Unsupported operating system: $OS"
  exit 1
  ;;
esac

print_success "Local setup complete 🚀"
print_line
