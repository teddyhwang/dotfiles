#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"

if ! command -v brew &>/dev/null; then
  if [ -f "/usr/local/bin/brew" ]; then
    BREW_BIN="/usr/local/bin/brew"
  else
    BREW_BIN="/opt/homebrew/bin/brew"
  fi
  print_progress "Installing Brew packages..."
  $BREW_BIN tap "homebrew/bundle"
  $BREW_BIN bundle
  "$($BREW_BIN --prefix)/opt/fzf/install" --all
else
  print_info "Brew bundled"
fi

if [ -d ~/Library/Application\ Support/Amethyst/ ]; then
  if ! [ -f ~/Library/Preferences/com.amethyst.Amethyst.plist ]; then
    print_progress "Copying Amethyst config file..."
    cp -rf ../apps/amethyst/com.amethyst.Amethyst.plist ~/Library/Preferences/com.amethyst.Amethyst.plist
    track_change
  else
    print_info "Amethyst config file is copied"
  fi

  if ! [ -f ~/Library/Application\ Support/Amethyst/Layouts/uniform-columns.js ]; then
    print_progress "Copying Amethyst custom layout file..."
    cp -rf ../apps/amethyst/uniform-columns.js ~/Library/Application\ Support/Amethyst/Layouts/uniform-columns.js
    track_change
  else
    print_info "Amethyst custom layout file is copied"
  fi
else
  print_warning "Amethyst not installed"
fi

if ! [ -f ~/Library/LaunchAgents/pbcopy.plist ]; then
  read -r -p "Do you want to setup pbcopy/pbpaste launch agents? (y/N) " response
  echo -e "\033[1A\033[2K\033[1A"
  if [[ "$response" =~ ^[Yy]$ ]]; then
    print_progress "Copying launch agent config files..."
    cp ../apps/pbcopy.plist ~/Library/LaunchAgents/.
    cp ../apps/pbpaste.plist ~/Library/LaunchAgents/.
    launchctl load ~/Library/LaunchAgents/pbcopy.plist
    launchctl load ~/Library/LaunchAgents/pbpaste.plist
    track_change
  else
    print_warning "Skipping launch agent setup"
  fi
else
  print_info "launch agent config files are copied"
fi

if [ -f ~/.gnupg/gpg-agent.conf ]; then
  if cat ~/.gnupg/gpg-agent.conf | grep -q pinentry-mac; then
    print_info "pinentry-mac is already set"
  else
    print_progress "Setting pinentry-mac..."
    touch ~/.gnupg/gpg-agent.conf
    echo "pinentry-program $(which pinentry-mac)" | tee ~/.gnupg/gpg-agent.conf
    track_change
  fi
else
  print_warning "gpg-agent not setup"
fi
