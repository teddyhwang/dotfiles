# shellcheck shell=bash
# Keep login and non-login interactive shells on the same initialization path.
# Non-interactive login shells still need the shared environment, but should
# not pay for interactive plugins.
if [[ $- == *i* ]]; then
  [[ -f "$HOME/.bashrc" ]] && . "$HOME/.bashrc"
else
  [[ -f "$HOME/.shared/env" ]] && . "$HOME/.shared/env"
fi

# Added by tec agent
_tec_init="$HOME/.local/state/tec/profiles/base/current/global/init"
if [[ -x "$_tec_init" ]]; then
  eval "$("$_tec_init" bash)"
fi
unset _tec_init
