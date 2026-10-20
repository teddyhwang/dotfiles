#!/bin/sh

set -eu

if [ "$#" -ne 0 ]; then
  printf 'Usage: sh %s\n' "$0" >&2
  exit 2
fi

if ! command -v node >/dev/null 2>&1; then
  printf 'pi.sh: node is required; install packages first (run setup.sh)\n' >&2
  exit 1
fi

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
exec node "$SCRIPT_DIR/pi_packages.mjs" "$SCRIPT_DIR/../apps/pi/packages.json"
