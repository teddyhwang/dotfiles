#!/bin/sh

# Rex keeps appearance settings in macOS defaults, not in init.lua. Write only
# the shared font and theme keys, so window frames, servers and other
# machine-specific preferences stay untouched.

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
# shellcheck source=utils.sh
. "$SCRIPT_DIR/utils.sh"

if [ "$(uname -s)" != Darwin ]; then
  print_info "Rex preferences are macOS-only; skipped."
  exit 0
fi

domain=com.superlogical.rex
preferences="$HOME/Library/Preferences/$domain.plist"
# defaults replaces a symlinked plist with a regular file; refuse instead.
if [ -L "$preferences" ]; then
  print_error "Refusing a symlinked Rex preferences file: $preferences"
  exit 1
fi

changed=0
# set_preference TYPE KEY VALUE. TYPE is string, int or bool.
set_preference() {
  type=$1 key=$2 value=$3
  expected=$value
  if [ "$type" = bool ]; then
    # defaults read prints booleans as 1 or 0.
    case "$value" in
      true) expected=1 ;;
      false) expected=0 ;;
      *) print_error "Invalid boolean for $key: $value"; exit 1 ;;
    esac
  fi
  current=$(defaults read "$domain" "$key" 2>/dev/null) || current=""
  [ "$current" = "$expected" ] && return 0
  defaults write "$domain" "$key" "-$type" "$value"
  changed=1
  track_change
}

set_preference string Workspace.terminalFontName "JetBrainsMono Nerd Font"
set_preference string Workspace.terminalFontStyle Regular
set_preference int Workspace.terminalFontPointSize 12
set_preference bool Workspace.terminalFontSmoothing true
set_preference string Workspace.interfaceStyle useTheme
set_preference string Workspace.darkThemeID merino-dark
set_preference string Workspace.lightThemeID merino-light

if [ "$changed" -eq 1 ] && pgrep -x Rex >/dev/null 2>&1; then
  print_info "Restart Rex to apply the font and theme preferences."
fi
print_conditional_success "Rex preferences"
