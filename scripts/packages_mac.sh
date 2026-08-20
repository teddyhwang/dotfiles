#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

# Ensure Homebrew is installed
. "${SCRIPT_DIR}/brew.sh"

if ! command -v brew >/dev/null 2>&1; then
  if [ -f "/usr/local/bin/brew" ]; then
    BREW_BIN="/usr/local/bin/brew"
  else
    BREW_BIN="/opt/homebrew/bin/brew"
  fi
  print_progress "Installing Brew packages..."
  "$BREW_BIN" bundle
  "$("$BREW_BIN" --prefix)/opt/fzf/install" --all
else
  BREW_BIN=$(command -v brew)
  print_info "Brew bundled"
fi

# setup.sh depends on Herdr after this script. `brew bundle` above only runs
# during a fresh Homebrew install, so also enforce this formula on existing
# Homebrew installations.
if ! "$BREW_BIN" list --formula herdr >/dev/null 2>&1; then
  print_progress "Installing Herdr..."
  "$BREW_BIN" install herdr
  track_change
else
  print_info "Herdr is installed"
fi

if [ -d ~/Library/Application\ Support/Amethyst/ ]; then
  if ! [ -f ~/Library/Preferences/com.amethyst.Amethyst.plist ]; then
    print_progress "Copying Amethyst config file..."
    cp -rf "${DOTFILES_DIR}/apps/amethyst/com.amethyst.Amethyst.plist" ~/Library/Preferences/com.amethyst.Amethyst.plist
    track_change
  else
    print_info "Amethyst config file is copied"
  fi

  if ! [ -f ~/Library/Application\ Support/Amethyst/Layouts/uniform-columns.js ]; then
    print_progress "Copying Amethyst custom layout file..."
    cp -rf "${DOTFILES_DIR}/apps/amethyst/uniform-columns.js" ~/Library/Application\ Support/Amethyst/Layouts/uniform-columns.js
    track_change
  else
    print_info "Amethyst custom layout file is copied"
  fi

  print_progress "Symlinking Amethyst YAML config..."
  validate_and_symlink "${DOTFILES_DIR}/apps/amethyst/amethyst.yml" "$HOME/.amethyst.yml"
else
  print_warning "Amethyst not installed"
fi

if ! [ -f ~/Library/LaunchAgents/pbcopy.plist ]; then
  printf "Do you want to setup pbcopy/pbpaste launch agents? (y/N) "
  read -r response
  printf "\033[1A\033[2K\033[1A"
  case "$response" in
  [Yy] | [Yy][Ee][Ss])
    print_progress "Copying launch agent config files..."
    cp "${DOTFILES_DIR}/apps/pbcopy.plist" ~/Library/LaunchAgents/.
    cp "${DOTFILES_DIR}/apps/pbpaste.plist" ~/Library/LaunchAgents/.
    launchctl load ~/Library/LaunchAgents/pbcopy.plist
    launchctl load ~/Library/LaunchAgents/pbpaste.plist
    track_change
    ;;
  *)
    print_warning "Skipping launch agent setup"
    ;;
  esac
else
  print_info "launch agent config files are copied"
fi

# Herdr tab auto-naming. hypr/autostart.lua starts this on Linux; launchd is the
# equivalent here. Reload whenever the plist changes so edits take effect.
herdr_agent=~/Library/LaunchAgents/herdr-tab-autoname.plist
if ! cmp -s "${DOTFILES_DIR}/apps/herdr-tab-autoname.plist" "$herdr_agent"; then
  print_progress "Installing herdr-tab-autoname launch agent..."
  cp "${DOTFILES_DIR}/apps/herdr-tab-autoname.plist" "$herdr_agent"
  launchctl unload "$herdr_agent" 2>/dev/null
  launchctl load "$herdr_agent"
  track_change
else
  print_info "herdr-tab-autoname launch agent is installed"
fi
