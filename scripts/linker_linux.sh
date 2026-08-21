#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

. "${SCRIPT_DIR}/linker.sh"

print_progress "\nSymlinking hypr config..."

for filepath in home/hypr/*; do
  entry_name=$(basename "$filepath")
  src_path="$DOTFILES_DIR/$filepath"
  dst_path="$HOME/.config/hypr/$entry_name"

  validate_and_symlink "$src_path" "$dst_path"
done

print_progress "\nSymlinking binaries..."

for filepath in home/local/bin/*; do
  entry_name=$(basename "$filepath")
  src_path="$DOTFILES_DIR/$filepath"
  dst_path="$HOME/.local/bin/$entry_name"

  validate_and_symlink "$src_path" "$dst_path"
done

print_progress "\nSymlinking keyd config..."

validate_and_symlink "$DOTFILES_DIR/home/keyd/app.conf" "$HOME/.config/keyd/app.conf"

if [ ! -f /etc/keyd/default.conf ]; then
  cp "$DOTFILES_DIR/home/keyd/default.conf" "/etc/keyd/default.conf"
fi

if [ -n "$OMARCHY_PATH" ]; then
  print_progress "\nSymlinking Omarchy..."
  mkdir -p "$HOME/.config/omarchy/hooks" "$HOME/.config/omarchy/plugins"
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
