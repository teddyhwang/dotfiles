#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
# shellcheck source=scripts/utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_status "Checking dependencies..."

# Apple's /usr/bin/git is a launcher even before Command Line Tools exist.
# Check CLT before invoking it so setup does not trigger a surprise GUI prompt.
if [ "$(uname -s)" = Darwin ] && ! xcode-select -p >/dev/null 2>&1; then
  print_error "Apple Command Line Tools are required. Run: xcode-select --install"
  print_error "Finish the installer, verify git --version, then rerun ./setup.sh."
  exit 1
fi

missing_deps=""

for cmd in curl git readlink; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing_deps="$missing_deps $cmd"
  fi
done

if [ -n "$missing_deps" ]; then
  print_error "Missing required dependencies:$missing_deps"
  print_error "Please install the following before running setup:"
  for dep in $missing_deps; do
    print_error "  - $dep"
  done
  exit 1
fi

if ! git --version >/dev/null 2>&1; then
  print_error "Git was found but cannot run. On macOS, finish installing Command Line Tools."
  print_error "Verify git --version before rerunning ./setup.sh."
  exit 1
fi

print_success "All required dependencies found"
