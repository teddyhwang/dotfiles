# shellcheck shell=bash
# Keep login and non-login interactive shells on the same initialization path.
# Non-interactive login shells still need the shared environment, but should
# not pay for interactive plugins.
if [[ $- == *i* ]]; then
  [[ -f "$HOME/.bashrc" ]] && . "$HOME/.bashrc"
else
  [[ -f "$HOME/.shared/env" ]] && . "$HOME/.shared/env"
fi
