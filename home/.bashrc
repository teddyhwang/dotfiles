# shellcheck shell=bash
# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

[[ -f "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"

[[ -f ~/.local/share/blesh/ble.sh ]] && source ~/.local/share/blesh/ble.sh --noattach
set -o vi

# Establish tool paths before looking for the prompt or Omarchy integrations.
[[ -f ~/.shared/env ]] && source ~/.shared/env

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
# Omarchy 4 ships these under /usr/share/omarchy; ~/.local/share/omarchy is
# only a back-compat symlink to it.
_omarchy_bash_rc="${OMARCHY_PATH:-/usr/share/omarchy}/default/bash/rc"
if [[ -f $_omarchy_bash_rc ]]; then
  source "$_omarchy_bash_rc"
else
  command -v starship &> /dev/null && eval "$(starship init bash)"
fi
unset _omarchy_bash_rc
if [[ -n "$DESKTOP_SESSION" ]]; then
  export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
  export SSH_ASKPASS="/usr/lib/seahorse/ssh-askpass"
  export SSH_ASKPASS_REQUIRE=prefer
fi

[[ -f ~/.shared/aliases ]] && source ~/.shared/aliases
[[ -f /usr/share/bash-preexec/bash-preexec.sh ]] && source /usr/share/bash-preexec/bash-preexec.sh
[[ -f ~/.shared/init ]] && source ~/.shared/init

[[ ${BLE_VERSION-} ]] && ble-attach

if [[ ${BLE_VERSION-} ]]; then
  ble-face -s auto_complete 'fg=240'

  ble-face -s filename_directory 'fg=111'
  ble-face -s filename_directory_sticky 'fg=111'
  ble-face -s cmdinfo_cd_cdpath 'fg=111'

  ble-bind -m auto_complete -f 'S-TAB' 'auto_complete/insert'
fi

[[ -f ~/.shared/functions ]] && source ~/.shared/functions

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Added by tec agent.
_tec_init="$HOME/.local/state/tec/profiles/base/current/global/init"
if [[ -x "$_tec_init" ]]; then
  eval "$("$_tec_init" bash)"
fi
unset _tec_init
