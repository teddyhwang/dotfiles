#!/bin/sh

set -eu

if [ "$#" -ne 0 ]; then
  printf 'Usage: sh %s\n' "$0" >&2
  exit 2
fi

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$SCRIPT_DIR/pi_packages.py" "$SCRIPT_DIR/../apps/pi/packages.json"
