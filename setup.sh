#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
cd "$SCRIPT_DIR"
# shellcheck source=scripts/utils.sh
. "${SCRIPT_DIR}/scripts/utils.sh"

if [ "$(id -u)" -eq 0 ]; then
  print_error "Do not run setup.sh as root; it manages files in your home directory."
  print_error "Run scripts/macbook_t2_linux.sh with sudo separately if this machine needs it."
  exit 1
fi

print_line
"${SCRIPT_DIR}/scripts/verify_dependencies.sh"
print_line
OS="$(uname -s)"
case "$OS" in
Darwin)
  print_progress "Installing Mac dependencies..."
  "${SCRIPT_DIR}/scripts/packages_mac.sh"
  # Keep Homebrew's PATH in the orchestrator, not just the package subprocess.
  # A first install launched from /bin/sh must expose tools to later steps.
  if command -v brew >/dev/null 2>&1; then
    brew_bin=$(command -v brew)
  elif [ -x /opt/homebrew/bin/brew ]; then
    brew_bin=/opt/homebrew/bin/brew
  else
    brew_bin=/usr/local/bin/brew
  fi
  brew_env=$("$brew_bin" shellenv sh)
  eval "$brew_env"
  "${SCRIPT_DIR}/scripts/verify_symlinks.sh"
  "${SCRIPT_DIR}/scripts/directories.sh"
  "${SCRIPT_DIR}/scripts/linker_mac.sh"
  "${SCRIPT_DIR}/scripts/services_mac.sh"
  "${SCRIPT_DIR}/scripts/herdr.sh"
  "${SCRIPT_DIR}/scripts/zsh.sh"
  "${SCRIPT_DIR}/scripts/bash.sh"
  "${SCRIPT_DIR}/scripts/tmux.sh"
  "${SCRIPT_DIR}/scripts/git_bat.sh"
  ;;
Linux)
  print_progress "Installing Linux dependencies..."
  "${SCRIPT_DIR}/scripts/packages_linux.sh"
  "${SCRIPT_DIR}/scripts/verify_symlinks.sh"
  "${SCRIPT_DIR}/scripts/directories.sh"
  "${SCRIPT_DIR}/scripts/linker_linux.sh"
  "${SCRIPT_DIR}/scripts/herdr.sh"
  "${SCRIPT_DIR}/scripts/bash.sh"
  "${SCRIPT_DIR}/scripts/tmux.sh"
  if command -v zsh >/dev/null 2>&1; then
    "${SCRIPT_DIR}/scripts/zsh.sh"
  fi
  "${SCRIPT_DIR}/scripts/git_bat.sh"
  print_info "T2 MacBook support is optional; run 'sudo ./scripts/macbook_t2_linux.sh' if needed."
  ;;
*)
  print_error "Unsupported operating system: $OS"
  exit 1
  ;;
esac

print_success "Local setup complete 🚀"
print_line
