#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

# Ensure Homebrew is installed and available in this process.
# shellcheck source=brew.sh
. "${SCRIPT_DIR}/brew.sh"

# Codex may be managed by npm (including on this workstation). Do not let
# Homebrew fail on the existing /opt/homebrew/bin/codex artifact; fresh systems
# without Codex still install the cask declared in Brewfile.
if command -v codex >/dev/null 2>&1 && ! "$BREW_BIN" list --cask codex >/dev/null 2>&1; then
  case " ${HOMEBREW_BUNDLE_CASK_SKIP:-} " in
    *" codex "*) ;;
    *) HOMEBREW_BUNDLE_CASK_SKIP="${HOMEBREW_BUNDLE_CASK_SKIP:+$HOMEBREW_BUNDLE_CASK_SKIP }codex" ;;
  esac
  export HOMEBREW_BUNDLE_CASK_SKIP
  print_info "Codex is managed outside Homebrew; skipping its cask"
fi

# Homebrew 6 requires explicit trust for third-party tap content. Trust only
# the exact artifacts declared here, never each tap's present and future code.
if "$BREW_BIN" command trust >/dev/null 2>&1; then
  "$BREW_BIN" trust --formula \
    airbytehq/tap/abctl \
    felixkratz/formulae/borders \
    shopify/shopify/ejson \
    shopify/shopify/ejson2env \
    tinted-theming/tinted/tinty \
    tw93/tap/mole >/dev/null
  "$BREW_BIN" trust --cask epk/epk/font-sf-mono-nerd-font >/dev/null
fi

print_progress "Installing Brewfile dependencies..."
if "$BREW_BIN" bundle check --no-upgrade --file "$DOTFILES_DIR/Brewfile" >/dev/null 2>&1; then
  print_info "Brewfile dependencies are installed"
else
  # A setup run should install missing dependencies, not unexpectedly upgrade
  # the entire workstation. Upgrades remain an explicit maintenance action.
  "$BREW_BIN" bundle install --no-upgrade --file "$DOTFILES_DIR/Brewfile"
  if ! "$BREW_BIN" bundle check --no-upgrade --file "$DOTFILES_DIR/Brewfile"; then
    print_error "Homebrew could not satisfy every Brewfile dependency"
    exit 1
  fi
  track_change
fi

fzf_install="$("$BREW_BIN" --prefix fzf 2>/dev/null)/install"
if [ -x "$fzf_install" ]; then
  "$fzf_install" --key-bindings --completion --no-update-rc >/dev/null
fi

if ! command -v herdr >/dev/null 2>&1; then
  print_error "Herdr is listed in Brewfile but is unavailable after installation"
  exit 1
fi

if [ -d "$HOME/Library/Application Support/Amethyst" ]; then
  if [ ! -f "$HOME/Library/Preferences/com.amethyst.Amethyst.plist" ]; then
    print_progress "Copying Amethyst config file..."
    cp "$DOTFILES_DIR/apps/amethyst/com.amethyst.Amethyst.plist" "$HOME/Library/Preferences/com.amethyst.Amethyst.plist"
    track_change
  else
    print_info "Amethyst config file is installed"
  fi

  if [ ! -f "$HOME/Library/Application Support/Amethyst/Layouts/uniform-columns.js" ]; then
    print_progress "Copying Amethyst custom layout file..."
    mkdir -p "$HOME/Library/Application Support/Amethyst/Layouts"
    cp "$DOTFILES_DIR/apps/amethyst/uniform-columns.js" "$HOME/Library/Application Support/Amethyst/Layouts/uniform-columns.js"
    track_change
  else
    print_info "Amethyst custom layout is installed"
  fi

  print_progress "Symlinking Amethyst YAML config..."
  validate_and_symlink "$DOTFILES_DIR/apps/amethyst/amethyst.yml" "$HOME/.amethyst.yml"
else
  print_warning "Amethyst is not installed"
fi

print_conditional_success "macOS packages"
