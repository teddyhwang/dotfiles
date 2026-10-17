#!/bin/sh
# Run only after binaries/configuration have been linked into HOME.

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

launch_agents="$HOME/Library/LaunchAgents"
launch_domain="gui/$(id -u)"
validate_home_target "$launch_agents/entry"
mkdir -p "$launch_agents"

ensure_agent() {
  name=$1
  label=$2
  agent="$launch_agents/$name.plist"
  validate_home_target "$agent" || return 1
  if ! cmp -s "$DOTFILES_DIR/apps/$name.plist" "$agent"; then
    if [ -e "$agent" ] || [ -L "$agent" ]; then
      if ! confirm "Replace differing $agent (preserving a backup)?"; then
        print_warning "Keeping existing $agent; skipping launch agent setup"
        return 0
      fi
      backup_root="$HOME/.local/state/dotfiles/backups"
      validate_home_target "$backup_root/entry" || return 1
      mkdir -p "$backup_root" || return 1
      backup_dir=$(mktemp -d "$backup_root/replaced.XXXXXX") || return 1
      mv -- "$agent" "$backup_dir/$name.plist" || return 1
      print_info "Preserved original at $backup_dir/$name.plist"
    elif ! confirm "Install loopback-only $name launch agent?"; then
      print_warning "Skipping $name launch agent setup"
      return 0
    fi
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

# Exact historical definitions from 7d20d5b and acba407. Do not infer
# ownership from the filename, label, or a substring of ProgramArguments.
legacy_agent_matches() {
  for runtime in typescript python; do
    if [ "$runtime" = typescript ]; then
      runtime_comment='the TypeScript daemon needs the
         Homebrew Node runtime and shells out to git.'
    else
      runtime_comment='the daemon shells out to git, and
         python3 may only exist under Homebrew.'
    fi
    if cmp -s "$agent" - <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>localhost.herdr-tab-autoname</string>
    <!-- launchd does not expand ~, and the daemon lives under \$HOME, so go
         through a shell that does. -->
    <key>ProgramArguments</key>
    <array>
      <string>/bin/sh</string>
      <string>-c</string>
      <string>exec "\$HOME/.local/bin/herdr-tab-autoname"</string>
    </array>
    <!-- launchd hands agents a minimal PATH; ${runtime_comment} -->
    <key>EnvironmentVariables</key>
    <dict>
      <key>PATH</key>
      <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>10</integer>
  </dict>
</plist>
EOF
    then
      return 0
    fi
  done
  return 1
}

remove_legacy_agent() {
  name=$1
  label=$2
  agent="$launch_agents/$name.plist"
  validate_home_target "$agent" || return 1
  if ! legacy_agent_matches; then
    print_warning "Preserving unverified legacy $name agent; no job will be unloaded"
    return 0
  fi
  if launchctl print "$launch_domain/$label" >/dev/null 2>&1; then
    print_progress "Removing legacy $name launch agent..."
    launchctl bootout "$launch_domain/$label"
    track_change
  fi
  rm -f "$agent"
  track_change
}

# Only byte-equal managed agents imply prior opt-in; each other destination
# requires explicit consent before any changes to its file or runtime state.
ensure_agent pbcopy localhost.pbcopy
ensure_agent pbpaste localhost.pbpaste

# Tab naming moved to an event-driven Herdr plugin. Remove the old resident
# process when upgrading an existing machine.
remove_legacy_agent herdr-tab-autoname localhost.herdr-tab-autoname

print_conditional_success "macOS launch agents"
