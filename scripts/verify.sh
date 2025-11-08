#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_status "Checking dependencies...\n"
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

print_success "All required dependencies found\n"
