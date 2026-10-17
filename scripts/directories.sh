#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

add_directory_in_home() {
  directory="$1"
  if ! [ -d "$HOME/$directory" ]; then
    print_success "Creating $directory folder..."
    mkdir -p "$HOME/$directory"
    track_change
  else
    print_info "$directory exists"
  fi
}

print_progress "Creating directories..."

add_directory_in_home '.config'
add_directory_in_home '.ssh'
add_directory_in_home '.local/bin'

# macOS-only: ~/Library does not exist on Linux.
if [ "$(uname -s)" = "Darwin" ]; then
  if ! [ -d ~/Library/Application\ Support/lazygit ]; then
    print_progress "Adding directory ~/Library/Application Support/lazygit..."
    mkdir -p ~/Library/Application\ Support/lazygit
    track_change
  else
    print_info "$HOME/Library/Application Support/lazygit exists"
  fi
fi

# Do not precreate Ghostty/btop directories: the linker installs their parent
# directories as symlinks. Theme hooks create their generated subdirectories.

# The tinty theme-set hook copies generated themes into these.
if ! [ -d "$HOME/.config/zed/themes" ]; then
  print_progress "Adding directory $HOME/.config/zed/themes..."
  mkdir -p "$HOME/.config/zed/themes"
  track_change
else
  print_info "$HOME/.config/zed/themes exists"
fi

print_conditional_success "Directories"
