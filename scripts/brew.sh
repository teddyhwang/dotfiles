#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

if ! command -v brew >/dev/null 2>&1; then
  print_progress "Installing Homebrew..."
  /bin/bash -c "$(curl --disable --fail --silent --show-error --location https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if command -v brew >/dev/null 2>&1; then
  BREW_BIN=$(command -v brew)
elif [ -x /opt/homebrew/bin/brew ]; then
  BREW_BIN=/opt/homebrew/bin/brew
elif [ -x /usr/local/bin/brew ]; then
  BREW_BIN=/usr/local/bin/brew
else
  print_error "Homebrew installation completed but brew could not be found"
  exit 1
fi

# Make a freshly installed Homebrew available to the rest of setup.
eval "$("$BREW_BIN" shellenv)"
export BREW_BIN
print_info "Homebrew is installed at $BREW_BIN"
