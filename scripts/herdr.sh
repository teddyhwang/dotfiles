#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

plugin_source="lmilojevicc/herdr-splits.nvim"
plugin_id="herdr-splits"
lazy_lock="$DOTFILES_DIR/home/config/nvim/lazy-lock.json"
expected_actions='["nav-left","nav-down","nav-up","nav-right","resize-left","resize-down","resize-up","resize-right"]'
tab_autoname_plugin_id="teddyhwang.tab-autoname"
tab_autoname_plugin_path="$DOTFILES_DIR/plugins/herdr-tab-autoname"
tab_autoname_events='["workspace.focused","tab.created","tab.closed","tab.renamed","tab.moved","tab.focused","pane.created","pane.closed","pane.moved","pane.exited","pane.agent_detected","pane.agent_status_changed"]'

print_progress "Ensuring Herdr plugins are installed..."

find_executable() {
  executable=$1
  if command -v "$executable" >/dev/null 2>&1; then
    command -v "$executable"
    return
  fi

  for prefix in /opt/homebrew/bin /usr/local/bin /usr/bin; do
    if [ -x "$prefix/$executable" ]; then
      printf '%s\n' "$prefix/$executable"
      return
    fi
  done

  return 1
}

if ! herdr_bin=$(find_executable herdr); then
  print_error "herdr is required before installing $plugin_source"
  exit 1
fi

if ! jq_bin=$(find_executable jq); then
  print_error "jq is required to verify Herdr plugins"
  exit 1
fi

# Neovim's lockfile is machine-local and may not exist until its first run.
# Prefer its revision when available; otherwise bootstrap with the last shared pin.
plugin_ref=""
if [ -e "$lazy_lock" ]; then
  if ! plugin_ref=$("$jq_bin" -r '."herdr-splits.nvim".commit // empty' "$lazy_lock"); then
    print_error "Could not read Neovim lockfile: $lazy_lock"
    exit 1
  fi
fi
if [ -z "$plugin_ref" ]; then
  plugin_ref="94f30cf4e9ac76ddf185a3acd0977be728fa4106"
  print_info "No local Neovim pin for $plugin_id; using setup's pinned revision $plugin_ref"
fi

plugin_matches() {
  # The dollar-prefixed names below are jq variables, not shell variables.
  # shellcheck disable=SC2016
  "$jq_bin" -e \
    --arg id "$plugin_id" \
    --arg owner "${plugin_source%%/*}" \
    --arg repo "${plugin_source#*/}" \
    --arg ref "$plugin_ref" \
    --argjson actions "$expected_actions" '
      any(.result.plugins[]?;
        .plugin_id == $id and
        .source.kind == "github" and
        .source.owner == $owner and
        .source.repo == $repo and
        .source.resolved_commit == $ref and
        (($actions - [.actions[].id]) | length == 0)
      )
    ' >/dev/null
}

plugin_enabled() {
  # shellcheck disable=SC2016
  "$jq_bin" -e --arg id "$plugin_id" \
    'any(.result.plugins[]?; .plugin_id == $id and .enabled == true)' >/dev/null
}

list_plugins() {
  "$herdr_bin" plugin list --json
}

if ! plugins_json=$(list_plugins); then
  print_error "Could not list installed Herdr plugins"
  exit 1
fi

if ! printf '%s' "$plugins_json" | plugin_matches; then
  print_progress "Installing $plugin_source at $plugin_ref..."
  "$herdr_bin" plugin install "$plugin_source" --ref "$plugin_ref" --yes
  track_change
  if ! plugins_json=$(list_plugins); then
    print_error "Could not list Herdr plugins after installation"
    exit 1
  fi
elif ! printf '%s' "$plugins_json" | plugin_enabled; then
  print_progress "Enabling $plugin_id..."
  "$herdr_bin" plugin enable "$plugin_id"
  track_change
  if ! plugins_json=$(list_plugins); then
    print_error "Could not list Herdr plugins after enabling $plugin_id"
    exit 1
  fi
else
  print_info "$plugin_id is installed, enabled, and matches revision $plugin_ref"
fi

if ! printf '%s' "$plugins_json" | plugin_matches || ! printf '%s' "$plugins_json" | plugin_enabled; then
  print_error "$plugin_id failed post-install verification"
  exit 1
fi

if [ ! -x "$HOME/.local/bin/herdr-tab-autoname" ]; then
  print_error "Link binaries before configuring $tab_autoname_plugin_id (run setup.sh)"
  exit 1
fi

tab_autoname_plugin_matches() {
  # shellcheck disable=SC2016
  "$jq_bin" -e \
    --arg id "$tab_autoname_plugin_id" \
    --arg manifest "$tab_autoname_plugin_path/herdr-plugin.toml" \
    --argjson events "$tab_autoname_events" '
      any(.result.plugins[]?;
        .plugin_id == $id and
        .manifest_path == $manifest and
        .enabled == true and
        any(.actions[]?; .id == "refresh") and
        (($events - [.events[].on]) | length == 0) and
        ((.warnings // []) | length == 0)
      )
    ' >/dev/null
}

if ! printf '%s' "$plugins_json" | tab_autoname_plugin_matches; then
  print_progress "Linking local $tab_autoname_plugin_id plugin..."
  "$herdr_bin" plugin link "$tab_autoname_plugin_path" --enabled
  track_change
  if ! plugins_json=$(list_plugins); then
    print_error "Could not list Herdr plugins after linking $tab_autoname_plugin_id"
    exit 1
  fi
else
  print_info "$tab_autoname_plugin_id is linked and enabled"
fi

if ! printf '%s' "$plugins_json" | tab_autoname_plugin_matches; then
  print_error "$tab_autoname_plugin_id failed post-link verification"
  exit 1
fi

# Linux autostart used to leave a resident event subscriber running. Its Unix
# socket is an unambiguous marker, so stop only that legacy process during the
# plugin migration. macOS removes the same process through services_mac.sh.
legacy_lock="${XDG_CACHE_HOME:-$HOME/.cache}/herdr-tab-autoname.lock"
if [ -S "$legacy_lock" ]; then
  if command -v lsof >/dev/null 2>&1; then
    legacy_pids=$(lsof -t "$legacy_lock" 2>/dev/null || true)
    for legacy_pid in $legacy_pids; do
      kill "$legacy_pid" 2>/dev/null || true
    done
  fi
  rm -f "$legacy_lock"
  track_change
fi

print_conditional_success "Herdr plugins"
