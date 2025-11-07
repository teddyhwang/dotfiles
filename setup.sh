#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/utils.sh
source "${SCRIPT_DIR}/scripts/utils.sh"

./scripts/verify.sh

print_status "Starting installation...\n"
OS="$(uname -s)"
case "$OS" in
Darwin)
  print_progress "Installing Mac dependencies..."
  ./scripts/mac.sh
  ./scripts/directories.sh
  ./scripts/linker.sh
  ./scripts/zsh.sh
  ./scripts/tmux.sh
  ./scripts/git-bat.sh
  ;;
Linux)
  print_progress "Installing Linux dependencies..."
  ./scripts/linker-linux.sh
  ./scripts/tmux.sh
  ./scripts/packages.sh
  ;;
*)
  print_error "Unsupported operating system: $OS"
  exit 1
  ;;
esac

print_success "Local setup complete 🚀"
