#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

plugin_source="lmilojevicc/herdr-splits.nvim"
plugin_id="herdr-splits"
lazy_lock="$DOTFILES_DIR/home/config/nvim/lazy-lock.json"
expected_actions='["nav-left","nav-down","nav-up","nav-right","resize-left","resize-down","resize-up","resize-right"]'

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

plugin_ref=$("$jq_bin" -r '."herdr-splits.nvim".commit // empty' "$lazy_lock")
if [ -z "$plugin_ref" ]; then
  print_error "No herdr-splits.nvim commit is pinned in $lazy_lock"
  exit 1
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
  print_info "$plugin_id is installed, enabled, and matches the Neovim lockfile"
fi

if ! printf '%s' "$plugins_json" | plugin_matches || ! printf '%s' "$plugins_json" | plugin_enabled; then
  print_error "$plugin_id failed post-install verification"
  exit 1
fi

print_conditional_success "Herdr plugins"
