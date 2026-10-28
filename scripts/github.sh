#!/bin/sh

set -eu

if ! command -v gh >/dev/null 2>&1; then
  printf 'GitHub setup: gh is required; rerun setup.sh to install dependencies.\n' >&2
  exit 1
fi

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  if [ ! -t 0 ]; then
    printf 'GitHub setup: login required. Run setup.sh in a terminal, or run gh auth login --hostname github.com followed by gh auth setup-git --hostname github.com.\n' >&2
    exit 1
  fi
  printf 'Sign in to GitHub to enable private extensions and Git HTTPS access.\n'
  gh auth login --hostname github.com --git-protocol https --web
fi

gh auth setup-git --hostname github.com
printf 'GitHub authentication and Git HTTPS credentials configured.\n'
