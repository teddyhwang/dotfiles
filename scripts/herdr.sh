#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

legacy_plugin_id="herdr-splits"
tab_autoname_plugin_id="teddyhwang.tab-autoname"
tab_autoname_plugin_path="$DOTFILES_DIR/plugins/herdr-tab-autoname"
tab_autoname_events='["workspace.focused","tab.created","tab.closed","tab.renamed","tab.moved","tab.focused","pane.created","pane.closed","pane.moved","pane.exited","pane.agent_detected","pane.agent_status_changed"]'
pickers_plugin_id="teddyhwang.pickers"
pickers_plugin_path="$DOTFILES_DIR/plugins/herdr-pickers"
pickers_panes='["workspace","agent","join-pane","worktree"]'

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
  print_error "herdr is required before configuring Herdr plugins"
  exit 1
fi

if ! jq_bin=$(find_executable jq); then
  print_error "jq is required to verify Herdr plugins"
  exit 1
fi

plugin_installed() {
  # shellcheck disable=SC2016
  "$jq_bin" -e --arg id "$1" 'any(.result.plugins[]?; .plugin_id == $id)' >/dev/null
}

list_plugins() {
  "$herdr_bin" plugin list --json
}

if ! plugins_json=$(list_plugins); then
  print_error "Could not list installed Herdr plugins"
  exit 1
fi

if printf '%s' "$plugins_json" | plugin_installed "$legacy_plugin_id"; then
  print_progress "Uninstalling $legacy_plugin_id (replaced by herdr-nav)..."
  "$herdr_bin" plugin uninstall "$legacy_plugin_id"
  track_change
  if ! plugins_json=$(list_plugins); then
    print_error "Could not list Herdr plugins after uninstalling $legacy_plugin_id"
    exit 1
  fi
  if printf '%s' "$plugins_json" | plugin_installed "$legacy_plugin_id"; then
    print_error "$legacy_plugin_id is still installed"
    exit 1
  fi
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

pickers_plugin_matches() {
  # shellcheck disable=SC2016
  "$jq_bin" -e \
    --arg id "$pickers_plugin_id" \
    --arg manifest "$pickers_plugin_path/herdr-plugin.toml" \
    --argjson panes "$pickers_panes" '
      any(.result.plugins[]?;
        .plugin_id == $id and
        .manifest_path == $manifest and
        .enabled == true and
        (($panes - [.panes[]?.id]) | length == 0) and
        ((.warnings // []) | length == 0)
      )
    ' >/dev/null
}

# Relinking a local plugin re-reads its manifest, so this also picks up
# manifest changes such as new events or panes.
ensure_linked_plugin() {
  linked_id=$1
  linked_path=$2
  linked_matches=$3
  if printf '%s' "$plugins_json" | "$linked_matches"; then
    print_info "$linked_id is linked and enabled"
    return
  fi

  print_progress "Linking local $linked_id plugin..."
  "$herdr_bin" plugin link "$linked_path" --enabled
  track_change
  if ! plugins_json=$(list_plugins); then
    print_error "Could not list Herdr plugins after linking $linked_id"
    exit 1
  fi
  if ! printf '%s' "$plugins_json" | "$linked_matches"; then
    print_error "$linked_id failed post-link verification"
    exit 1
  fi
}

ensure_linked_plugin "$tab_autoname_plugin_id" "$tab_autoname_plugin_path" tab_autoname_plugin_matches
ensure_linked_plugin "$pickers_plugin_id" "$pickers_plugin_path" pickers_plugin_matches

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
