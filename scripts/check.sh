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

for command_name in bash git jq node python3 ruby shellcheck sh zsh; do
  require_command "$command_name"
done

printf 'Checking shell syntax...\n'
for file in setup.sh scripts/*.sh; do
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
  home/local/bin/fix-windows.sh \
  home/local/bin/tinty-herdr-hook \
  home/local/bin/tinty-opencode-hook \
  home/config/tmux/resurrect-guard.sh \
  home/omarchy/hooks/theme-set; do
  bash -n "$file"
done
for file in home/.zshrc home/.p10k.zsh home/shared/aliases home/shared/env home/shared/functions home/shared/init; do
  zsh -n "$file"
done

printf 'Running ShellCheck...\n'
shellcheck -x -S warning \
  -e SC1090,SC1091,SC2262,SC2263 \
  setup.sh scripts/*.sh \
  home/.bash_profile home/.bashrc \
  home/shared/aliases home/shared/env home/shared/functions home/shared/init \
  home/local/bin/fix-windows.sh \
  home/local/bin/herdr-tab-autoname \
  home/local/bin/tinty-herdr-hook \
  home/local/bin/tinty-opencode-hook \
  home/local/bin/trackpad-auto-toggle \
  home/config/tmux/resurrect-guard.sh \
  home/omarchy/hooks/theme-set

printf 'Checking structured config files...\n'
python3 - <<'PY'
import json
import os
import pathlib
import subprocess
import tomllib

def strip_jsonc(source):
    output = []
    index = 0
    in_string = False
    escaped = False
    while index < len(source):
        char = source[index]
        next_char = source[index + 1] if index + 1 < len(source) else ""
        if in_string:
            output.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
        elif char == '"':
            in_string = True
            output.append(char)
            index += 1
        elif char == "/" and next_char == "/":
            index += 2
            while index < len(source) and source[index] != "\n":
                index += 1
        elif char == "/" and next_char == "*":
            index += 2
            while index + 1 < len(source) and source[index:index + 2] != "*/":
                if source[index] == "\n":
                    output.append("\n")
                index += 1
            index += 2
        else:
            output.append(char)
            index += 1

    source = "".join(output)
    output = []
    index = 0
    in_string = False
    escaped = False
    while index < len(source):
        char = source[index]
        if in_string:
            output.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
        elif char == '"':
            in_string = True
            output.append(char)
            index += 1
        elif char == ",":
            lookahead = index + 1
            while lookahead < len(source) and source[lookahead].isspace():
                lookahead += 1
            if lookahead < len(source) and source[lookahead] in "}]":
                index += 1
                continue
            output.append(char)
            index += 1
        else:
            output.append(char)
            index += 1
    return "".join(output)


files = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard"], text=True
).splitlines()
for filename in files:
    path = pathlib.Path(filename)
    if path.suffix in {".json", ".jsonc", ".plist", ".toml", ".yaml", ".yml"} and os.access(path, os.X_OK):
        raise ValueError(f"{filename}: configuration files must not be executable")

    try:
        source = path.read_text()
    except UnicodeDecodeError:
        continue

    if source and not source.endswith("\n"):
        raise ValueError(f"{filename}: missing final newline")
    for line_number, line in enumerate(source.splitlines(), 1):
        if line.endswith((" ", "\t")):
            raise ValueError(f"{filename}:{line_number}: trailing whitespace")

    if path.suffix in {".json", ".jsonc"}:
        is_jsonc = path.suffix == ".jsonc" or path.as_posix() == "home/config/zed/settings.json"
        json.loads(strip_jsonc(source) if is_jsonc else source)
    elif path.suffix == ".toml":
        tomllib.loads(source)

compile(pathlib.Path("home/local/bin/herdr-even-layout").read_text(), "herdr-even-layout", "exec")
for path in pathlib.Path("scripts").glob("*.py"):
    compile(path.read_text(), str(path), "exec")
PY

ruby - <<'RUBY'
require "yaml"
`git ls-files "*.yml" "*.yaml"`.lines(chomp: true).each do |file|
  YAML.safe_load_file(file, aliases: true)
end
RUBY

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
