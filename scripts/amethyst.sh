#!/bin/sh

set -eu

restore_preferences=0
case "$#" in
  0) ;;
  1) if [ "$1" = --restore-preferences ]; then restore_preferences=1; else
       printf 'Usage: sh %s [--restore-preferences]\n' "$0" >&2; exit 1
     fi ;;
  *) printf 'Usage: sh %s [--restore-preferences]\n' "$0" >&2; exit 1 ;;
esac

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "$SCRIPT_DIR/utils.sh"

preferences="$HOME/Library/Preferences/com.amethyst.Amethyst.plist"
layout="$HOME/Library/Application Support/Amethyst/Layouts/uniform-columns.js"
state_root="$HOME/.local/state/dotfiles"
backup_root="$state_root/backups"
# Validate all destinations before creating directories or querying defaults.
for destination in "$preferences" "$layout" "$HOME/.amethyst.yml" "$state_root/entry" "$backup_root/entry"; do
  validate_home_target "$destination" || exit 1
done
# defaults may follow an existing preferences symlink; never import through one.
if [ -L "$preferences" ]; then
  print_error "Refusing a symlinked Amethyst preferences file: $preferences"
  exit 1
fi
mkdir -p -- "$(dirname -- "$preferences")"
validate_and_symlink "$DOTFILES_DIR/apps/amethyst/amethyst.yml" "$HOME/.amethyst.yml"
validate_and_symlink "$DOTFILES_DIR/apps/amethyst/uniform-columns.js" "$layout"

domain=com.amethyst.Amethyst
existing_preferences=0
if [ -e "$preferences" ] || defaults read "$domain" >/dev/null 2>&1; then
  existing_preferences=1
fi
if [ "$existing_preferences" -eq 1 ] && [ "$restore_preferences" -eq 0 ]; then
  print_info "Keeping existing Amethyst preferences (including stock defaults)."
  print_info "To reset settings and shortcuts, quit Amethyst, then run: sh \"$SCRIPT_DIR/amethyst.sh\" --restore-preferences"
  print_conditional_success "Amethyst"
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  print_error "node is required to prepare Amethyst preferences; install packages first (run setup.sh). No preferences were changed."
  exit 1
fi

if pgrep -x Amethyst >/dev/null 2>&1; then
  print_error "Quit Amethyst before importing preferences; no preferences were changed."
  exit 1
else
  pgrep_status=$?
  if [ "$pgrep_status" -ne 1 ]; then
    print_error "Could not determine whether Amethyst is running; refusing import."
    exit 1
  fi
fi

umask 077
mkdir -p -- "$state_root"
work_dir=$(mktemp -d "$state_root/amethyst.XXXXXX")
trap 'rm -rf -- "$work_dir"' 0
trap 'exit 1' HUP INT TERM
chmod 700 "$work_dir"
current_plist=""
if [ "$existing_preferences" -eq 1 ]; then
  mkdir -p -- "$backup_root"
  backup_dir=$(mktemp -d "$backup_root/amethyst.XXXXXX")
  chmod 700 "$backup_dir"
  current_plist="$backup_dir/preferences.plist"
  if ! defaults export "$domain" "$current_plist"; then
    print_error "Could not export existing Amethyst preferences; refusing import. Backup directory: $backup_dir"
    exit 1
  fi
  chmod 600 "$current_plist"
  print_info "Amethyst preferences backed up at $current_plist"
fi
if ! node "$SCRIPT_DIR/amethyst_preferences.mjs" \
  "$DOTFILES_DIR/apps/amethyst/com.amethyst.Amethyst.plist" \
  "$work_dir/preferences.plist" "$current_plist"; then
  print_error "Could not prepare Amethyst preferences; refusing import."
  exit 1
fi
# defaults import merges keys rather than replacing the domain. Delete only
# after a successful backup and preparation, never for a fresh absent domain.
if [ "$existing_preferences" -eq 1 ]; then
  if ! defaults delete "$domain"; then
    print_error "Could not delete existing Amethyst preferences; refusing import. Backup preserved at $current_plist"
    exit 1
  fi
fi
if ! defaults import "$domain" "$work_dir/preferences.plist"; then
  print_error "Could not import Amethyst preferences."
  if [ "$existing_preferences" -eq 1 ]; then
    # A failed import may have written some keys. Clear them before rollback
    # so merging the backup cannot retain new keys from the failed profile.
    rollback_ready=1
    if [ -e "$preferences" ] || defaults read "$domain" >/dev/null 2>&1; then
      if ! defaults delete "$domain"; then
        rollback_ready=0
      fi
    fi
    if [ "$rollback_ready" -eq 1 ] && defaults import "$domain" "$current_plist"; then
      print_warning "Rollback succeeded: restored original Amethyst preferences from $current_plist"
    else
      print_error "Rollback failed. Keep Amethyst closed and recover from the preserved backup: $current_plist"
    fi
  fi
  exit 1
fi
track_change
print_info "Launch Amethyst manually and grant Accessibility access if requested."
print_conditional_success "Amethyst"
