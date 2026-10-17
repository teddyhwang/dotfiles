#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Setting up bash..."

BLESH_DIR="$HOME/.local/share/blesh"

validate_home_target "$BLESH_DIR"
if [ -f "$BLESH_DIR/ble.sh" ] && [ -r "$BLESH_DIR/ble.sh" ]; then
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
  mkdir -p -- "$(dirname -- "$BLESH_DIR")"
  tmp_dir=$(mktemp -d "$(dirname -- "$BLESH_DIR")/.dotfiles-blesh.XXXXXX")
  trap 'rm -rf -- "$tmp_dir"' 0
  trap 'exit 1' HUP INT TERM
  git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git "$tmp_dir/ble.sh"
  # Upstream supports PREFIX and INSDIR_DOC; keep docs with the staged payload.
  make -C "$tmp_dir/ble.sh" install PREFIX="$tmp_dir/prefix" INSDIR_DOC="$tmp_dir/prefix/share/blesh/doc"
  staged_dir="$tmp_dir/prefix/share/blesh"
  if [ ! -f "$staged_dir/ble.sh" ] || [ ! -r "$staged_dir/ble.sh" ]; then
    print_error "ble.sh installation did not produce a readable ble.sh"
    exit 1
  fi

  if [ -e "$BLESH_DIR" ] || [ -L "$BLESH_DIR" ]; then
    backup_root="$HOME/.local/state/dotfiles/backups"
    validate_home_target "$backup_root/entry"
    mkdir -p -- "$backup_root"
    backup_dir=$(mktemp -d "$backup_root/blesh.XXXXXX")
    mv -- "$BLESH_DIR" "$backup_dir/blesh"
    print_info "Preserved incomplete ble.sh at $backup_dir/blesh"
  fi
  mv -- "$staged_dir" "$BLESH_DIR"
  rm -rf -- "$tmp_dir"
  trap - 0 HUP INT TERM
  track_change
fi

print_conditional_success "Bash"
