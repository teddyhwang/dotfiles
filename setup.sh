#!/bin/zsh

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/scripts/print.sh"

print_status "Starting installation...\n"

./scripts/omz.sh
./scripts/directories.sh
./scripts/linker.sh
./scripts/dependencies.sh
./scripts/plugins.sh
./scripts/tmux.sh
./scripts/git-bat.sh
if [ $SPIN ]; then
  ./scripts/spin.sh
fi

print_success "Local setup complete 🚀"
