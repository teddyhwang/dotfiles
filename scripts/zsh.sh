#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Setting up Zsh..."

ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
validate_home_target "$ZINIT_HOME"
if [ -f "$ZINIT_HOME/zinit.zsh" ] && [ -r "$ZINIT_HOME/zinit.zsh" ]; then
  print_info "zinit is installed"
else
  print_progress "Installing zinit..."
  mkdir -p "$(dirname -- "$ZINIT_HOME")"
  tmp_dir=$(mktemp -d "$(dirname -- "$ZINIT_HOME")/.dotfiles-zinit.XXXXXX")
  trap 'rm -rf -- "$tmp_dir"' 0
  trap 'exit 1' HUP INT TERM
  git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$tmp_dir/zinit.git"
  if [ ! -f "$tmp_dir/zinit.git/zinit.zsh" ] || [ ! -r "$tmp_dir/zinit.git/zinit.zsh" ]; then
    print_error "zinit installation did not produce a readable zinit.zsh"
    exit 1
  fi

  if [ -e "$ZINIT_HOME" ] || [ -L "$ZINIT_HOME" ]; then
    backup_root="$HOME/.local/state/dotfiles/backups"
    validate_home_target "$backup_root/entry"
    mkdir -p -- "$backup_root"
    backup_dir=$(mktemp -d "$backup_root/zinit.XXXXXX")
    mv -- "$ZINIT_HOME" "$backup_dir/zinit.git"
    print_info "Preserved incomplete zinit at $backup_dir/zinit.git"
  fi
  mv -- "$tmp_dir/zinit.git" "$ZINIT_HOME"
  rm -rf -- "$tmp_dir"
  trap - 0 HUP INT TERM
  track_change
fi

for completion in "$DOTFILES_DIR"/home/completions/*; do
  [ -f "$completion" ] || continue
  destination="$HOME/.zsh/completions/$(basename -- "$completion")"
  validate_and_symlink "$completion" "$destination"
done

print_conditional_success "Zsh"
