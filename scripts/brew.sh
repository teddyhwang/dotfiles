#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

if ! command -v brew >/dev/null 2>&1 &&
  [ ! -x /opt/homebrew/bin/brew ] && [ ! -x /usr/local/bin/brew ]; then
  print_progress "Installing Homebrew..."
  # Download separately: a failed curl inside bash -c "$(...)" otherwise looks
  # like a successful empty script. Bound network waits on fresh machines.
  installer=$(mktemp "${TMPDIR:-/tmp}/dotfiles-homebrew.XXXXXX")
  trap 'rm -f "$installer"' 0
  trap 'exit 1' HUP INT TERM
  curl --disable --fail --silent --show-error --location \
    --connect-timeout 10 --max-time 120 \
    https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh >"$installer"
  /bin/bash "$installer"
  rm -f "$installer"
  trap - 0 HUP INT TERM
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
brew_env=$("$BREW_BIN" shellenv sh)
eval "$brew_env"
unset brew_env
export BREW_BIN
print_info "Homebrew is installed at $BREW_BIN"
