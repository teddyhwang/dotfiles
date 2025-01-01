#!/bin/zsh

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/print.sh"

function add_directory_in_home {
  directory=$1
  if ! [ -d ~/$directory ]; then
    print_success "Creating $directory folder..."
    mkdir ~/$directory
  else
    print_info "$directory exists"
  fi
}

add_directory_in_home '.config'
add_directory_in_home '.ssh'
add_directory_in_home '.bin'

if ! [ -d /usr/local/bin ]; then
  print_success "Adding directory /usr/local/bin..."
  sudo mkdir /usr/local/bin
else
  print_info "/usr/local/bin/ exists"
fi

if ! [ -d ~/Library/Application\ Support/lazygit ]; then
  print_success "Adding directory ~/Library/Application Support/lazygit..."
  sudo mkdir ~/Library/Application\ Support/lazygit
else
  print_info "~/Library/Application Support/lazygit exists"
fi

