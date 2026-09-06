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

print_progress "\nInstalling keyd config..."

validate_and_symlink "$DOTFILES_DIR/home/keyd/app.conf" "$HOME/.config/keyd/app.conf"

keyd_source="$DOTFILES_DIR/home/keyd/default.conf"
keyd_target="/etc/keyd/default.conf"
install_keyd_config=0
keep_existing_keyd_config=0
if [ ! -e "$keyd_target" ]; then
  install_keyd_config=1
elif ! cmp -s "$keyd_source" "$keyd_target"; then
  if confirm "$keyd_target differs; replace it?"; then
    install_keyd_config=1
  else
    keep_existing_keyd_config=1
  fi
fi

if [ "$install_keyd_config" -eq 1 ]; then
  if [ "$(id -u)" -eq 0 ]; then
    install -m 0644 "$keyd_source" "$keyd_target"
  elif command -v sudo >/dev/null 2>&1; then
    sudo install -m 0644 "$keyd_source" "$keyd_target"
  else
    print_error "sudo is required to install $keyd_target"
    exit 1
  fi
  track_change

  if command -v systemctl >/dev/null 2>&1; then
    if [ "$(id -u)" -eq 0 ]; then
      systemctl enable --now keyd.service
    else
      sudo systemctl enable --now keyd.service
    fi
  fi
elif [ "$keep_existing_keyd_config" -eq 1 ]; then
  print_warning "Keeping the existing $keyd_target"
else
  print_info "$keyd_target is already configured"
fi

if [ -n "${OMARCHY_PATH:-}" ]; then
  print_progress "\nSymlinking Omarchy..."
  mkdir -p "$HOME/.config/omarchy/extensions" "$HOME/.config/omarchy/hooks" "$HOME/.config/omarchy/plugins"
  validate_and_symlink "$DOTFILES_DIR/home/omarchy/extensions/omarchy-menu.jsonc" "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
  validate_and_symlink "$DOTFILES_DIR/home/omarchy/hooks/theme-set" "$HOME/.config/omarchy/hooks/theme-set"
  validate_and_symlink "$DOTFILES_DIR/home/omarchy/plugins/teddyhwang.menu" "$HOME/.config/omarchy/plugins/teddyhwang.menu"

  # The menu clone adds Vim-style Ctrl+J/K navigation. Enabling it replaces
  # the built-in menu while preserving its stable omarchy.menu IPC target.
  if omarchy-shell shell rescanPlugins >/dev/null 2>&1; then
    omarchy plugin enable teddyhwang.menu >/dev/null
    omarchy restart shell >/dev/null
  else
    print_warning "Omarchy shell is not running; enable teddyhwang.menu after login."
  fi
fi

print_conditional_success "Symlinks"
