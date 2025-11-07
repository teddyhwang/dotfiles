#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"

add_directory_in_home() {
  local directory="$1"
  if ! [ -d "$HOME/$directory" ]; then
    print_success "Creating $directory folder..."
    mkdir "$HOME/$directory"
    track_change
  else
    print_info "$directory exists"
  fi
}

print_progress "\nCreating directories..."

add_directory_in_home '.config'
add_directory_in_home '.ssh'
add_directory_in_home '.bin'

if ! [ -d /usr/local/bin ]; then
  print_progress "Adding directory /usr/local/bin..."
  sudo mkdir /usr/local/bin
  track_change
else
  print_info "/usr/local/bin/ exists"
fi

if ! [ -d ~/Library/Application\ Support/lazygit ]; then
  print_progress "Adding directory ~/Library/Application Support/lazygit..."
  sudo mkdir ~/Library/Application\ Support/lazygit
  track_change
else
  print_info "$HOME/Library/Application Support/lazygit exists"
fi

if ! [ -d "$HOME/.config/ghostty/themes" ]; then
  print_progress "Adding directory $HOME/.config/ghostty/themes..."
  mkdir -p "$HOME/.config/ghostty/themes"
  track_change
else
  print_info "$HOME/.config/ghostty/themes exists"
fi

print_conditional_success "Directories"
