#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
DOTFILES_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
cd "$DOTFILES_DIR"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'check: required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

for command_name in bash git jq node shellcheck sh taplo yq zsh; do
  require_command "$command_name"
done
# Arch's `yq` package is a different, jq-based tool; use go-yq there.
if ! yq --version 2>&1 | grep -q mikefarah; then
  printf 'check: yq must be mikefarah/yq (Homebrew yq, Arch go-yq)\n' >&2
  exit 1
fi

printf 'Checking shell syntax...\n'
for file in bootstrap.sh setup.sh scripts/*.sh plugins/herdr-tab-autoname/schedule.sh; do
  [[ "$file" == "scripts/check.sh" ]] && continue
  sh -n "$file"
done
for file in \
  scripts/check.sh \
  home/.bash_profile \
  home/.bashrc \
  home/shared/aliases \
  home/shared/env \
  home/shared/functions \
  home/shared/init \
  home/local/bin/external-display-stay-awake \
  home/local/bin/fix-windows.sh \
  home/local/bin/tinty-herdr-hook \
  home/local/bin/wayvnc-output-recover \
  home/local/bin/zed-test-file \
  home/config/tmux/resurrect-guard.sh \
  home/omarchy/hooks/theme-set \
  plugins/herdr-pickers/picker.sh; do
  bash -n "$file"
done
for file in home/.zshenv home/.zshrc home/.p10k.zsh home/shared/aliases home/shared/env home/shared/functions home/shared/init; do
  zsh -n "$file"
done

printf 'Running ShellCheck...\n'
shellcheck -x -S warning \
  -e SC1090,SC1091,SC2262,SC2263 \
  bootstrap.sh setup.sh scripts/*.sh plugins/herdr-tab-autoname/schedule.sh plugins/herdr-pickers/picker.sh \
  home/.bash_profile home/.bashrc \
  home/shared/aliases home/shared/env home/shared/functions home/shared/init \
  home/local/bin/external-display-stay-awake \
  home/local/bin/fix-windows.sh \
  home/local/bin/herdr-tab-autoname \
  home/local/bin/tinty-herdr-hook \
  home/local/bin/trackpad-auto-toggle \
  home/local/bin/wayvnc-output-recover \
  home/local/bin/zed-test-file \
  home/config/tmux/resurrect-guard.sh \
  home/omarchy/hooks/theme-set

printf 'Checking files, JSON and Node syntax...\n'
node scripts/check_files.mjs

printf 'Checking structured config files...\n'
toml_files=()
while IFS= read -r file; do
  [[ -f "$file" ]] && toml_files+=("$file")
done < <(git ls-files --cached --others --exclude-standard '*.toml')
if ((${#toml_files[@]})); then
  RUST_LOG=warn taplo check --colors never --no-auto-config "${toml_files[@]}"
fi
while IFS= read -r file; do
  yq eval '.' "$file" >/dev/null
done < <(git ls-files '*.yml' '*.yaml')

if command -v luac >/dev/null 2>&1; then
  while IFS= read -r file; do
    luac -p "$file"
  done < <(git ls-files '*.lua')
fi
if command -v plutil >/dev/null 2>&1; then
  while IFS= read -r file; do
    plutil -lint "$file" >/dev/null
  done < <(git ls-files '*.plist')
fi

printf 'Checking for committed credential patterns...\n'
credential_pattern='(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-(proj-)?[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY)'
if git grep -nE "$credential_pattern" -- . ':!apps/*.rayconfig'; then
  printf 'check: possible committed credential found\n' >&2
  exit 1
fi

printf 'Running tests...\n'
node --test tests/*.test.mjs

printf 'Checking repository whitespace...\n'
git diff --check

printf 'All checks passed.\n'
