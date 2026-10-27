#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

# shellcheck source=linker.sh
. "${SCRIPT_DIR}/linker.sh"

print_progress "\nSymlinking Hammerspoon config..."

validate_and_symlink "$DOTFILES_DIR/home/.hammerspoon" "$HOME/.hammerspoon"

print_progress "\nSymlinking gpg-agent config..."

# The config names Apple Silicon Homebrew's pinentry-mac path.
if [ -x /opt/homebrew/bin/pinentry-mac ]; then
  [ -d "$HOME/.gnupg" ] || mkdir -m 700 -- "$HOME/.gnupg"
  validate_and_symlink "$DOTFILES_DIR/home/gnupg/gpg-agent.conf" "$HOME/.gnupg/gpg-agent.conf"
else
  print_warning "Skipping gpg-agent.conf: /opt/homebrew/bin/pinentry-mac is missing"
fi

print_progress "\nSymlinking binaries..."

for filepath in "$DOTFILES_DIR"/home/local/bin/*; do
  [ -e "$filepath" ] || [ -L "$filepath" ] || continue
  [ -d "$filepath" ] && [ ! -L "$filepath" ] && continue
  entry_name=$(basename -- "$filepath")
  dst_path="$HOME/.local/bin/$entry_name"

  validate_and_symlink "$filepath" "$dst_path"
done

print_conditional_success "Symlinking"
