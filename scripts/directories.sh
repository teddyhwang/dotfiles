#!/bin/zsh

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/print.sh"

function add_directory_in_home {
  directory=$1
  if ! [ -d ~/$directory ]; then
    print_success "Creating $directory folder..."
    mkdir ~/$directory
    track_change
  else
    print_info "$directory exists"
  fi
}

print_progress "Creating directories..."

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
  print_info "~/Library/Application Support/lazygit exists"
fi

print_conditional_success "Directories"
