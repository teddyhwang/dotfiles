#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
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

if ! [ -d /usr/local/bin ]; then
  print_progress "Adding directory /usr/local/bin..."
  sudo mkdir /usr/local/bin
  track_change
else
  print_info "/usr/local/bin/ exists"
fi

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

if ! [ -d "$HOME/.config/ghostty/themes" ]; then
  print_progress "Adding directory $HOME/.config/ghostty/themes..."
  mkdir -p "$HOME/.config/ghostty/themes"
  track_change
else
  print_info "$HOME/.config/ghostty/themes exists"
fi

# The tinty theme-set hook copies generated themes into these.
if ! [ -d "$HOME/.config/zed/themes" ]; then
  print_progress "Adding directory $HOME/.config/zed/themes..."
  mkdir -p "$HOME/.config/zed/themes"
  track_change
else
  print_info "$HOME/.config/zed/themes exists"
fi

if ! [ -d "$HOME"/.config/btop/themes ]; then
  print_progress "Adding directory $HOME/.config/btop/themes..."
  mkdir -p "$HOME"/.config/btop/themes
  track_change
else
  print_info "$HOME/.config/btop/themes exists"
fi

print_conditional_success "Directories"
