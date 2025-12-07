#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

. "${SCRIPT_DIR}/linker.sh"

print_progress "\nSymlinking binaries..."

for filepath in home/bin/*; do
  file=$(basename "$filepath")
  source="$(pwd)/$filepath"
  target="$HOME/.bin/$file"

  validate_and_symlink "$source" "$target"
done

print_conditional_success "Symlinking"
