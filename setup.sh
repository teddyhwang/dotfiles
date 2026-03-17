#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/utils.sh
. "${SCRIPT_DIR}/scripts/utils.sh"

print_line
"${SCRIPT_DIR}/scripts/verify_dependencies.sh"
print_line
OS="$(uname -s)"
case "$OS" in
Darwin)
  print_progress "Installing Mac dependencies..."
  "${SCRIPT_DIR}/scripts/packages_mac.sh"
  "${SCRIPT_DIR}/scripts/verify_symlinks.sh"
  "${SCRIPT_DIR}/scripts/directories.sh"
  "${SCRIPT_DIR}/scripts/linker_mac.sh"
  "${SCRIPT_DIR}/scripts/zsh.sh"
  "${SCRIPT_DIR}/scripts/bash.sh"
  "${SCRIPT_DIR}/scripts/tmux.sh"
  "${SCRIPT_DIR}/scripts/git_bat.sh"
  ;;
Linux)
  print_progress "Installing Linux dependencies..."
  "${SCRIPT_DIR}/scripts/packages_linux.sh"
  "${SCRIPT_DIR}/scripts/verify_symlinks.sh"
  "${SCRIPT_DIR}/scripts/linker_linux.sh"
  "${SCRIPT_DIR}/scripts/bash.sh"
  "${SCRIPT_DIR}/scripts/tmux.sh"
  if command -v zsh >/dev/null 2>&1; then
    "${SCRIPT_DIR}/scripts/zsh.sh"
  fi
  "${SCRIPT_DIR}/scripts/git_bat.sh"
  if [ -n "$SUDO_USER" ] || [ "$(id -u)" -eq 0 ]; then
    "${SCRIPT_DIR}/scripts/macbook_t2_linux.sh"
  else
    print_warning "Skipping T2 MacBook setup (requires sudo). Run 'sudo ./scripts/macbook_t2_linux.sh' if needed."
  fi
  ;;
*)
  print_error "Unsupported operating system: $OS"
  exit 1
  ;;
esac

print_success "Local setup complete 🚀"
print_line
