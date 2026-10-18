#!/bin/sh
# Standalone entry point: download this file before Git/Homebrew are available.
set -eu

fail() {
  printf 'bootstrap: %s\n' "$1" >&2
  exit 1
}

main() {
  [ "$(uname -s)" = Darwin ] || fail "This bootstrap is for macOS. Use setup.sh directly on supported Linux systems."
  [ "$(id -u)" -ne 0 ] || fail "Run as your normal macOS user, not with sudo."
  case "${HOME:-}" in
    '' | /) fail "HOME must be a non-root absolute directory." ;;
    /*) ;;
    *) fail "HOME must be an absolute directory." ;;
  esac
  home_real=$(CDPATH='' cd -- "$HOME" && pwd -P) || fail "Cannot access HOME."
  [ "$home_real" != / ] || fail "HOME must not resolve to root."

  # Keep the script's input separate from installation prompts, including when
  # invoked with redirected stdin. Homebrew/setup must retain an actual TTY.
  if ! ( : </dev/tty ) 2>/dev/null; then
    fail "Open Terminal and run this command interactively; a controlling terminal is required."
  fi
  exec 3</dev/tty

  if ! xcode-select -p >/dev/null 2>&1; then
    printf 'Apple Command Line Tools are missing. Opening the installer...\n'
    if ! xcode-select --install; then
      fail "Could not open the Command Line Tools installer. Install them in Software Update, then rerun bootstrap."
    fi
    printf 'Finish the installation window, then press Return here to continue: '
    IFS= read -r _answer <&3 || fail "Installation not confirmed. Finish Command Line Tools installation, then rerun bootstrap."
    xcode-select -p >/dev/null 2>&1 || fail "Command Line Tools are not ready. Finish installing them, then rerun bootstrap."
  fi
  git --version >/dev/null 2>&1 || fail "Git cannot run. Finish Command Line Tools installation, then rerun bootstrap."

  repository=https://github.com/teddyhwang/dotfiles.git
  parent="$home_real/src/github.com/teddyhwang"
  checkout="$parent/dotfiles"

  # Refuse to create a checkout through parents that escape the user's HOME.
  ancestor=$parent
  while [ ! -e "$ancestor" ] && [ ! -L "$ancestor" ]; do
    ancestor=$(dirname -- "$ancestor")
  done
  ancestor_real=$(CDPATH='' cd -- "$ancestor" && pwd -P) || fail "Cannot access checkout parent."
  case "$ancestor_real" in
    "$home_real" | "$home_real"/*) ;;
    *) fail "Checkout parent resolves outside HOME; refusing to write there." ;;
  esac
  [ ! -L "$checkout" ] || fail "Checkout path is a symlink; refusing to replace or follow it."

  if [ -e "$checkout" ]; then
    [ -d "$checkout" ] || fail "Checkout path already exists and is not a directory: $checkout"
    actual_root=$(git -C "$checkout" rev-parse --show-toplevel 2>/dev/null) || fail "Existing destination is not a Git checkout: $checkout"
    [ "$actual_root" = "$(CDPATH='' cd -- "$checkout" && pwd -P)" ] || fail "Existing destination is not a repository root: $checkout"
    origin=$(git -C "$checkout" remote get-url origin 2>/dev/null) || fail "Existing checkout has no origin remote."
    case "$origin" in
      https://github.com/teddyhwang/dotfiles | https://github.com/teddyhwang/dotfiles.git | git@github.com:teddyhwang/dotfiles | git@github.com:teddyhwang/dotfiles.git) ;;
      *) fail "Existing checkout has a different origin; refusing to run it: $origin" ;;
    esac
    printf 'Reusing %s without pulling or changing your local work.\n' "$checkout"
  else
    mkdir -p "$parent"
    staging=$(mktemp -d "$parent/.dotfiles-bootstrap.XXXXXX")
    trap 'rm -rf -- "$staging"' 0
    trap 'exit 1' HUP INT TERM
    printf 'Cloning the public dotfiles repository over HTTPS...\n'
    # Stage the clone so an interrupted download never poisons the destination.
    GIT_TERMINAL_PROMPT=0 git clone --branch main -- "$repository" "$staging/repository"
    if [ -e "$checkout" ] || [ -L "$checkout" ]; then
      fail "Checkout path appeared during the download; refusing to replace it."
    fi
    mv -- "$staging/repository" "$checkout"
    rm -rf -- "$staging"
    trap - 0 HUP INT TERM
  fi

  [ -f "$checkout/setup.sh" ] && [ -r "$checkout/setup.sh" ] || fail "Checkout has no readable setup.sh."
  printf 'Running setup. Enter your Mac password when Homebrew requests it.\n'
  if /bin/sh "$checkout/setup.sh" <&3; then
    printf '\nSetup succeeded. Open a new Terminal window, or run: exec /bin/zsh -l\n'
    printf 'Manual sign-ins, permissions and keys: %s/docs/mac-setup.md\n' "$checkout"
  else
    result=$?
    printf '\nbootstrap: Setup failed (exit %s). Fix the reported error and rerun:\n' "$result" >&2
    printf '  /bin/sh "%s/setup.sh"\n' "$checkout" >&2
    exit "$result"
  fi
}

main "$@"
