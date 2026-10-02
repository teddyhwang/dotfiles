#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Symlinking dotfiles..."

for filepath in "$DOTFILES_DIR"/home/.[!.]*; do
  [ -e "$filepath" ] || [ -L "$filepath" ] || continue
  entry_name=$(basename -- "$filepath")
  dst_path="$HOME/$entry_name"

  # Skip mac-only dotfiles.
  [ "$entry_name" = ".hammerspoon" ] && continue

  validate_and_symlink "$filepath" "$dst_path"
done

validate_and_symlink "$DOTFILES_DIR/home/shared" "$HOME/.shared"

print_progress "\nSymlinking config directories..."

for filepath in "$DOTFILES_DIR"/home/config/*; do
  [ -e "$filepath" ] || [ -L "$filepath" ] || continue
  entry_name=$(basename -- "$filepath")
  dst_path="$HOME/.config/$entry_name"

  # Symlink individual files for configs that shouldn't have the whole dir tracked.
  case "$entry_name" in
    opencode | tmux | opensessions | zed | herdr)
      mkdir -p "$dst_path"
      for subfile in "$filepath"/*; do
        [ -e "$subfile" ] || [ -L "$subfile" ] || continue
        subfile_dst="$dst_path/$(basename -- "$subfile")"
        validate_and_symlink "$subfile" "$subfile_dst"
      done
      continue
      ;;
  esac

  validate_and_symlink "$filepath" "$dst_path"
done

print_progress "\nSymlinking Claude config..."

mkdir -p "$HOME/.claude"
for filepath in "$DOTFILES_DIR"/home/claude/*; do
  [ -e "$filepath" ] || [ -L "$filepath" ] || continue
  entry_name=$(basename -- "$filepath")
  dst_path="$HOME/.claude/$entry_name"

  validate_and_symlink "$filepath" "$dst_path"
done

print_progress "\nSymlinking pi agent config..."

mkdir -p "$HOME/.pi/agent"
# Personal Pi extensions now live in the installed teddyhwang/pi-extensions
# package. Retire only our exact legacy symlink; never remove another installer's
# files or a user-maintained copy.
legacy_pi_extension="$HOME/.pi/agent/extensions/session-tab-name.ts"
canonical_pi_extension="$HOME/.pi/agent/git/github.com/teddyhwang/pi-extensions/extensions/session-tab-name/index.ts"
if [ -L "$legacy_pi_extension" ] && \
  [ "$(readlink "$legacy_pi_extension")" = "$DOTFILES_DIR/home/pi-agent/extensions/session-tab-name.ts" ]; then
  if [ -f "$canonical_pi_extension" ]; then
    rm -- "$legacy_pi_extension"
  else
    print_warning "Install teddyhwang/pi-extensions before retiring the legacy session-tab-name symlink"
  fi
fi

# A copied definition is ours only when it carries this marker. Other user and
# installer definitions are never replaced or removed.
pi_agent_marker="# Managed by dotfiles: "

managed_pi_agent_source() {
  sed -n "s|^$pi_agent_marker\\(home/pi-agent/agents/[A-Za-z0-9/_.-]*\\.md\\)\$|\\1|p" "$1" | head -n 1
}

install_pi_agent_definitions() {
  for definition in "$1"/*.md; do
    [ -f "$definition" ] || continue
    target="$2/$(basename -- "$definition")"
    validate_home_target "$target" || return 1
    # Retire the symlink an earlier linker created for this definition.
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$definition" ]; then
      rm -- "$target"
    fi
    if [ -e "$target" ] || [ -L "$target" ]; then
      if [ -L "$target" ] || [ -z "$(managed_pi_agent_source "$target")" ]; then
        print_warning "Keeping existing agent definition $target"
        continue
      fi
      if cmp -s "$definition" "$target"; then
        print_info "$target is up to date."
        continue
      fi
    fi
    # Never write through a leftover temp path, and never leave one behind.
    rm -f -- "$target.dotfiles-tmp"
    if ! cp -- "$definition" "$target.dotfiles-tmp"; then
      rm -f -- "$target.dotfiles-tmp"
      return 1
    fi
    mv -f -- "$target.dotfiles-tmp" "$target" || return 1
    print_success "Installed $target"
    track_change
  done
}

# Remove our copies whose source is gone, or work copies on a personal machine.
prune_pi_agent_definitions() {
  for target in "$1"/*.md; do
    [ -f "$target" ] && [ ! -L "$target" ] || continue
    source_path=$(managed_pi_agent_source "$target")
    [ -n "$source_path" ] || continue
    case "$source_path" in
      home/pi-agent/agents/work/*) [ "$2" -eq 1 ] || source_path="" ;;
    esac
    if [ -z "$source_path" ] || [ ! -f "$DOTFILES_DIR/$source_path" ]; then
      rm -- "$target"
      print_success "Removed $target"
      track_change
    fi
  done
}

for filepath in "$DOTFILES_DIR"/home/pi-agent/*; do
  [ -e "$filepath" ] || [ -L "$filepath" ] || continue
  entry_name=$(basename -- "$filepath")
  dst_path="$HOME/.pi/agent/$entry_name"

  # Extension implementation belongs in the canonical Pi package, not dotfiles.
  if [ "$entry_name" = "extensions" ]; then
    print_error "Pi extensions must live in https://github.com/teddyhwang/pi-extensions"
    exit 1
  fi

  # Copy agent definitions: Herdsman ignores symlinked ones. Work definitions
  # depend on the Shopify AI proxy, so they install only where devx exists.
  if [ "$entry_name" = "agents" ]; then
    # Prune deletes files, so the directory itself must resolve inside HOME.
    validate_home_target "$dst_path/definition.md" || exit 1
    mkdir -p "$dst_path"
    work_machine=0
    command -v devx >/dev/null 2>&1 && work_machine=1
    prune_pi_agent_definitions "$dst_path" "$work_machine"
    install_pi_agent_definitions "$filepath" "$dst_path"
    if [ "$work_machine" -eq 1 ]; then
      install_pi_agent_definitions "$filepath/work" "$dst_path"
    fi
    continue
  fi

  validate_and_symlink "$filepath" "$dst_path"
done
