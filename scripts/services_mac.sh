#!/bin/sh
# Run only after binaries/configuration have been linked into HOME.

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

launch_agents="$HOME/Library/LaunchAgents"
launch_domain="gui/$(id -u)"
mkdir -p "$launch_agents"

ensure_agent() {
  name=$1
  label=$2
  agent="$launch_agents/$name.plist"
  if ! cmp -s "$DOTFILES_DIR/apps/$name.plist" "$agent"; then
    print_progress "Installing $name launch agent..."
    # Unload the old definition before replacing it.
    launchctl bootout "$launch_domain/$label" 2>/dev/null || true
    cp "$DOTFILES_DIR/apps/$name.plist" "$agent"
    track_change
  fi
  # File equality alone does not imply the job is loaded (e.g. after a failed
  # bootstrap or a manual bootout). A rerun must repair that state too.
  if ! launchctl print "$launch_domain/$label" >/dev/null 2>&1; then
    launchctl bootstrap "$launch_domain" "$agent"
    track_change
  else
    print_info "$name launch agent is loaded"
  fi
}

# Existing clipboard agents imply prior opt-in. New installations still ask.
if { [ -f "$launch_agents/pbcopy.plist" ] && [ -f "$launch_agents/pbpaste.plist" ]; } ||
  confirm "Do you want to set up loopback-only pbcopy/pbpaste launch agents?"; then
  ensure_agent pbcopy localhost.pbcopy
  ensure_agent pbpaste localhost.pbpaste
else
  print_warning "Skipping clipboard launch agent setup"
fi

if [ ! -x "$HOME/.local/bin/herdr-tab-autoname" ]; then
  print_error "Link binaries before configuring launch agents (run setup.sh)"
  exit 1
fi
ensure_agent herdr-tab-autoname localhost.herdr-tab-autoname

print_conditional_success "macOS launch agents"
