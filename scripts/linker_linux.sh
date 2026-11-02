#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

# shellcheck source=linker.sh
. "${SCRIPT_DIR}/linker.sh"

print_progress "\nSymlinking hypr config..."

for filepath in "$DOTFILES_DIR"/home/hypr/*; do
  [ -e "$filepath" ] || [ -L "$filepath" ] || continue
  entry_name=$(basename -- "$filepath")
  dst_path="$HOME/.config/hypr/$entry_name"

  validate_and_symlink "$filepath" "$dst_path"
done

print_progress "\nSymlinking binaries..."

for filepath in "$DOTFILES_DIR"/home/local/bin/*; do
  [ -e "$filepath" ] || [ -L "$filepath" ] || continue
  [ -d "$filepath" ] && [ ! -L "$filepath" ] && continue
  entry_name=$(basename -- "$filepath")
  dst_path="$HOME/.local/bin/$entry_name"

  validate_and_symlink "$filepath" "$dst_path"
done

print_progress "\nSymlinking systemd user services..."

mkdir -p "$HOME/.config/systemd/user"
for filepath in "$DOTFILES_DIR"/home/systemd/user/*; do
  [ -e "$filepath" ] || [ -L "$filepath" ] || continue
  [ -d "$filepath" ] && [ ! -L "$filepath" ] && continue
  entry_name=$(basename -- "$filepath")
  dst_path="$HOME/.config/systemd/user/$entry_name"

  validate_and_symlink "$filepath" "$dst_path"
done

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload || print_warning "Could not reload the systemd user manager"
fi

print_progress "\nRetiring keyd..."

# home/hypr/bindings.lua now provides the macOS-style Super shortcuts that keyd
# used to remap. keyd only sees physical keyboards, so WayVNC and Deskflow,
# which type through virtual keyboards, never got them. While keyd runs, its
# remaps win over Hyprland for physical keyboards.
legacy_keyd_app_conf="$HOME/.config/keyd/app.conf"
if [ -L "$legacy_keyd_app_conf" ] && \
  [ "$(readlink "$legacy_keyd_app_conf")" = "$DOTFILES_DIR/home/keyd/app.conf" ]; then
  rm -- "$legacy_keyd_app_conf"
  track_change
fi

if command -v systemctl >/dev/null 2>&1; then
  if systemctl --user is-enabled --quiet keyd-application-mapper.service 2>/dev/null; then
    systemctl --user disable --now keyd-application-mapper.service
    track_change
  fi

  if systemctl is-enabled --quiet keyd.service 2>/dev/null; then
    if confirm "Hyprland now handles keyd's shortcuts; disable keyd.service?"; then
      if [ "$(id -u)" -eq 0 ]; then
        systemctl disable --now keyd.service
      else
        sudo systemctl disable --now keyd.service
      fi
      track_change
    else
      print_warning "keyd.service is still enabled; its remaps override Hyprland on physical keyboards"
    fi
  fi
fi

if [ -n "${OMARCHY_PATH:-}" ]; then
  print_progress "\nSymlinking Omarchy..."
  mkdir -p "$HOME/.config/omarchy/extensions" "$HOME/.config/omarchy/hooks" "$HOME/.config/omarchy/plugins"
  validate_and_symlink "$DOTFILES_DIR/home/omarchy/extensions/omarchy-menu.jsonc" "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
  validate_and_symlink "$DOTFILES_DIR/home/omarchy/hooks/theme-set" "$HOME/.config/omarchy/hooks/theme-set"
  validate_and_symlink "$DOTFILES_DIR/home/omarchy/plugins/teddyhwang.menu" "$HOME/.config/omarchy/plugins/teddyhwang.menu"
  validate_and_symlink "$DOTFILES_DIR/home/omarchy/plugins/teddyhwang.workspaces" "$HOME/.config/omarchy/plugins/teddyhwang.workspaces"

  # The menu clone adds Vim-style Ctrl+J/K navigation. Enabling it replaces
  # the built-in menu while preserving its stable omarchy.menu IPC target.
  # The workspaces clone always shows 1-4 instead of the built-in 1-5.
  if omarchy-shell shell rescanPlugins >/dev/null 2>&1; then
    omarchy plugin enable teddyhwang.menu >/dev/null
    omarchy plugin enable teddyhwang.workspaces >/dev/null
    omarchy restart shell >/dev/null
  else
    print_warning "Omarchy shell is not running; enable teddyhwang.menu and teddyhwang.workspaces after login."
  fi
fi

print_conditional_success "Symlinks"
