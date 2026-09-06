#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
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
  tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-blesh.XXXXXX")
  trap 'rm -rf "$tmp_dir"' 0 HUP INT TERM
  git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git "$tmp_dir/ble.sh"
  make -C "$tmp_dir/ble.sh" install PREFIX="$HOME/.local"
  rm -rf "$tmp_dir"
  trap - 0 HUP INT TERM
  track_change
fi

print_conditional_success "Bash"
