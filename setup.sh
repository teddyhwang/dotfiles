#!/bin/zsh

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/print.sh"

print_status "Starting installation...\n"

./omz.sh
./directories.sh
./linker.sh
./dependencies.sh
./plugins.sh
./tmux.sh
./git-bat.sh
if [ $SPIN ]; then
  ./spin.sh
fi

print_success "Local setup complete 🚀"
