#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/utils.sh
source "${SCRIPT_DIR}/scripts/utils.sh"

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
  ./scripts/directories.sh
  ./scripts/linker.sh
  ./scripts/zsh.sh
  ./scripts/tmux.sh
  ./scripts/git-bat.sh
  ;;
Linux)
  print_progress "Installing Linux dependencies..."
  ./scripts/linux.sh
  ./scripts/tmux.sh
  ;;
*)
  print_error "Unsupported operating system: $OS"
  exit 1
  ;;
esac

print_success "Local setup complete 🚀"
