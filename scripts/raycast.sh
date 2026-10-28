#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
# shellcheck source=utils.sh
. "$SCRIPT_DIR/utils.sh"

explicit=0
archive=${RAYCAST_CONFIG_FILE:-"$HOME/.config/dotfiles/raycast.rayconfig"}
case "$#" in
  0) ;;
  1) if [ "$1" = --import ]; then explicit=1; else
       printf 'Usage: sh %s [--import [FILE]]\n' "$0" >&2; exit 1
     fi ;;
  2) if [ "$1" = --import ]; then explicit=1; archive=$2; else
       printf 'Usage: sh %s [--import [FILE]]\n' "$0" >&2; exit 1
     fi ;;
  *) printf 'Usage: sh %s [--import [FILE]]\n' "$0" >&2; exit 1 ;;
esac

if [ "$(uname -s)" != Darwin ]; then
  print_info "Raycast import is macOS-only; skipped."
  exit 0
fi

instructions() {
  print_info "Export from Raycast to a private .rayconfig archive (default: \$HOME/.config/dotfiles/raycast.rayconfig)."
  print_info "Then run: sh \"$SCRIPT_DIR/raycast.sh\" --import [FILE]"
  print_info "Complete category selection and any passphrase prompt in Raycast; keep the passphrase outside this repository."
}

case "$archive" in
  *.rayconfig) valid_extension=1 ;;
  *) valid_extension=0 ;;
esac
if [ "$valid_extension" -ne 1 ] || [ ! -f "$archive" ] || [ ! -r "$archive" ] || [ ! -s "$archive" ]; then
  if [ "$explicit" -eq 1 ]; then
    print_error "Raycast import requires a readable, nonempty regular .rayconfig file."
    instructions
    exit 1
  fi
  print_info "No usable private Raycast archive; skipping import."
  instructions
  exit 0
fi

if [ "$explicit" -eq 0 ]; then
  if [ ! -t 0 ]; then
    print_info "Noninteractive setup: skipping Raycast import; existing settings are unchanged."
    instructions
    exit 0
  fi
  if ! confirm "Open the private Raycast archive for manual import? This may replace settings selected in Raycast."; then
    print_info "Raycast import skipped; existing settings are unchanged."
    instructions
    exit 0
  fi
fi

# Absolute paths prevent open from treating relative filenames as options.
case "$archive" in
  /*) ;;
  *) archive="$(pwd -P)/$archive" ;;
esac
if ! open -a Raycast "$archive"; then
  print_error "Could not open the Raycast archive; import was not confirmed."
  exit 1
fi
print_info "Raycast archive opened for manual import, not confirmed as imported."
print_info "Select categories and enter any archive passphrase in Raycast's UI."
