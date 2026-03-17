#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Setting up bash..."

BLESH_DIR="$HOME/.local/share/blesh"

if [ -d "$BLESH_DIR" ]; then
  print_info "ble.sh is already installed"
else
  if ! command -v make >/dev/null 2>&1; then
    print_error "make is required to install ble.sh"
    exit 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    print_error "git is required to install ble.sh"
    exit 1
  fi

  print_progress "Installing ble.sh..."
  TMPDIR=$(mktemp -d)
  git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git "$TMPDIR/ble.sh"
  make -C "$TMPDIR/ble.sh" install PREFIX=~/.local
  rm -rf "$TMPDIR"
  track_change
fi

print_conditional_success "Bash"
