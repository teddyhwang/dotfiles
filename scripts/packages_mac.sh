#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

# Ensure Homebrew is installed and available in this process.
# shellcheck source=brew.sh
. "${SCRIPT_DIR}/brew.sh"

if command -v devx >/dev/null 2>&1; then
  BREWFILE="${DOTFILES_DIR}/Brewfile.work"
  print_info "devx detected; using the work Mac Brewfile"
else
  BREWFILE="${DOTFILES_DIR}/Brewfile"
  print_info "devx not detected; using the personal Brewfile"
fi
if [ ! -f "$BREWFILE" ]; then
  print_error "Brewfile not found: $BREWFILE"
  exit 1
fi

# Codex may be managed by npm (including on this workstation). Do not let
# Homebrew fail on the existing /opt/homebrew/bin/codex artifact; fresh systems
# without Codex still install the cask declared in the selected Brewfile.
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
    felixkratz/formulae/borders \
    shopify/shopify/ejson \
    shopify/shopify/ejson2env \
    tinted-theming/tinted/tinty \
    tw93/tap/mole >/dev/null
  "$BREW_BIN" trust --cask epk/epk/font-sf-mono-nerd-font >/dev/null
fi

print_progress "Installing Brewfile dependencies..."
if "$BREW_BIN" bundle check --no-upgrade --file "$BREWFILE" >/dev/null 2>&1; then
  print_info "Brewfile dependencies are installed"
else
  # A setup run should install missing dependencies, not unexpectedly upgrade
  # the entire workstation. Upgrades remain an explicit maintenance action.
  "$BREW_BIN" bundle install --no-upgrade --file "$BREWFILE"
  if ! "$BREW_BIN" bundle check --no-upgrade --file "$BREWFILE"; then
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

# Provision before first launch too; never launch or restart the app here.
sh "$SCRIPT_DIR/amethyst.sh"

print_conditional_success "macOS packages"
