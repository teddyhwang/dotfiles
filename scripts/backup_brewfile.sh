#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

if command -v brew >/dev/null 2>&1; then
  BREW_BIN=$(command -v brew)
elif [ -x /opt/homebrew/bin/brew ]; then
  BREW_BIN=/opt/homebrew/bin/brew
elif [ -x /usr/local/bin/brew ]; then
  BREW_BIN=/usr/local/bin/brew
else
  print_error "Homebrew is not installed"
  exit 1
fi

BACKUP_FILE=${BREWFILE_BACKUP_FILE:-"${DOTFILES_DIR}/Brewfile.work"}
backup_dir=$(dirname -- "$BACKUP_FILE")
if [ ! -d "$backup_dir" ]; then
  print_error "Backup directory does not exist: $backup_dir"
  exit 1
fi
backup_dir=$(CDPATH='' cd -- "$backup_dir" && pwd -P)
BACKUP_FILE="${backup_dir}/$(basename -- "$BACKUP_FILE")"

if [ "$BACKUP_FILE" = "${DOTFILES_DIR}/Brewfile" ]; then
  print_error "Refusing to overwrite the curated personal Brewfile"
  exit 1
fi

bundle_dump=$(mktemp "${backup_dir}/.Brewfile.dump.XXXXXX")
snapshot=$(mktemp "${backup_dir}/.Brewfile.snapshot.XXXXXX")
cleanup() {
  rm -f "$bundle_dump" "$snapshot"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

print_progress "Saving this Mac's Homebrew state to $BACKUP_FILE..."
HOMEBREW_NO_AUTO_UPDATE=1 "$BREW_BIN" bundle dump \
  --force \
  --no-describe \
  --no-vscode \
  --no-go \
  --no-cargo \
  --no-uv \
  --no-npm \
  --file "$bundle_dump"

{
  printf '%s\n' '# Generated from the work Mac; do not edit by hand.'
  printf '%s\n' '# Refresh with: ./scripts/backup_brewfile.sh'
  cat "$bundle_dump"
} >"$snapshot"
chmod 0644 "$snapshot"

mv "$snapshot" "$BACKUP_FILE"
rm -f "$bundle_dump"
trap - 0 HUP INT TERM
print_success "Homebrew snapshot saved to $BACKUP_FILE"
