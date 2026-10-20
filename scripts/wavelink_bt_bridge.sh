#!/bin/sh
# Builds wavelink-bt-bridge and runs it as a launch agent. The helper plays an
# Elgato Wave Link mix on Bluetooth headphones; see
# apps/wavelink-bt-bridge/README.md. setup.sh does not run this script.
#
# Usage: scripts/wavelink_bt_bridge.sh [install|build|uninstall]

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

name=wavelink-bt-bridge
label=localhost.wavelink-bt-bridge
source_dir="$DOTFILES_DIR/apps/$name"
binary="$HOME/.local/bin/$name"
agent="$HOME/Library/LaunchAgents/$label.plist"
domain="gui/$(id -u)"
# Set when the binary or the agent changes, so a loaded agent restarts.
restart=0

require_macos() {
  if [ "$(uname -s)" != Darwin ]; then
    print_error "$name runs only on macOS"
    exit 1
  fi
  if ! xcrun --find swiftc >/dev/null 2>&1; then
    print_error "swiftc is missing; install the Command Line Tools with: xcode-select --install"
    exit 1
  fi
}

build() {
  require_macos
  validate_home_target "$binary"
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  print_progress "Building $name..."
  # The embedded Info.plist names the binary and explains the microphone
  # request, which macOS shows before any app may read an audio input.
  xcrun swiftc -O -swift-version 5 -parse-as-library -target "$(uname -m)-apple-macos15" \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$source_dir/Info.plist" \
    -o "$work/$name" "$source_dir/$name.swift"
  codesign --force --sign - --identifier "$label" "$work/$name"
  if ! "$work/$name" --self-test >"$work/self-test.log" 2>&1; then
    cat "$work/self-test.log" >&2
    print_error "$name failed its self-test; nothing was installed"
    exit 1
  fi
  if cmp -s "$work/$name" "$binary"; then
    print_info "$binary is up to date"
  else
    mkdir -p "$(dirname -- "$binary")"
    mv -f "$work/$name" "$binary"
    track_change
    restart=1
    print_info "Installed $binary"
  fi
}

install_agent() {
  build
  validate_home_target "$agent"
  mkdir -p "$(dirname -- "$agent")" "$HOME/Library/Logs"
  # HOME goes into sed and XML unescaped, so refuse the characters that are
  # special in either.
  case "$HOME" in
    *[\&\<\>\|\\]*)
      print_error "HOME contains a character that the launch agent cannot hold: $HOME"
      exit 1
      ;;
  esac
  sed "s|@HOME@|$HOME|g" "$source_dir/launch-agent.plist" >"$work/agent.plist"
  if ! cmp -s "$work/agent.plist" "$agent"; then
    launchctl bootout "$domain/$label" 2>/dev/null || true
    mv -f "$work/agent.plist" "$agent"
    track_change
    restart=1
    print_info "Installed $agent"
  fi
  if ! launchctl print "$domain/$label" >/dev/null 2>&1; then
    launchctl bootstrap "$domain" "$agent"
    track_change
  elif [ "$restart" -eq 1 ]; then
    launchctl kickstart -k "$domain/$label"
  fi
  print_conditional_success "$name"
  print_info "Log: $HOME/Library/Logs/$name.log"
}

uninstall() {
  validate_home_target "$agent"
  validate_home_target "$binary"
  # The helper gives the default output back to the headset when it stops.
  if launchctl print "$domain/$label" >/dev/null 2>&1; then
    launchctl bootout "$domain/$label"
    track_change
  fi
  for file in "$agent" "$binary"; do
    if [ -e "$file" ] || [ -L "$file" ]; then
      rm -f -- "$file"
      track_change
    fi
  done
  print_conditional_success "$name removal"
}

case "${1:-install}" in
  install) install_agent ;;
  build) build ;;
  uninstall) uninstall ;;
  *)
    printf 'Usage: %s [install|build|uninstall]\n' "$0" >&2
    exit 2
    ;;
esac
