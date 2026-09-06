#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Installing tmux plugins..."
plugins="$HOME/.config/tmux/plugins"
tpm="$plugins/tpm"
tmux_bin=$(command -v tmux)

# A dedicated socket prevents setup from creating panes, loading plugins, or
# changing options in the user's running tmux server. Keep the socket path
# short enough for macOS's Unix-domain socket limit.
tmp_dir=$(mktemp -d /tmp/dotfiles-tmux.XXXXXX)
trap '"$tmux_bin" -S "$tmp_dir/server" kill-server 2>/dev/null || true; rm -rf "$tmp_dir"' 0
trap 'exit 1' HUP INT TERM

if [ ! -e "$tpm" ]; then
  print_progress "Installing tmux plugin manager..."
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$tmp_dir/tpm"
  mkdir -p "$plugins"
  mv "$tmp_dir/tpm" "$tpm"
  track_change
elif [ ! -x "$tpm/bin/install_plugins" ]; then
  print_error "Incomplete TPM install at $tpm; move it aside and rerun setup"
  exit 1
fi

unset TMUX
"$tmux_bin" -S "$tmp_dir/server" -f /dev/null start-server \; \
  set-option -g exit-empty off \; \
  set-environment -g TMUX_PLUGIN_MANAGER_PATH "$plugins/"

# TPM invokes `tmux` internally. Route only those invocations to our server.
export DOTFILES_TMUX_BIN="$tmux_bin" DOTFILES_TMUX_SOCKET="$tmp_dir/server"
cat >"$tmp_dir/tmux" <<'EOF'
#!/bin/sh
exec "$DOTFILES_TMUX_BIN" -S "$DOTFILES_TMUX_SOCKET" -f /dev/null "$@"
EOF
chmod +x "$tmp_dir/tmux"

# TPM is idempotent: check every declared plugin, not a single sentinel dir.
PATH="$tmp_dir:$PATH" XDG_CONFIG_HOME="$HOME/.config" "$tpm/bin/install_plugins"
print_success "All declared tmux plugins checked"
