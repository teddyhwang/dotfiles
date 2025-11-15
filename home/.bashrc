# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

[[ -f "$HOME/.local/share/../bin/env" ]] && . "$HOME/.local/share/../bin/env"

# Don't load ble.sh over SSH to avoid double-typing issues
[[ -z "$SSH_CONNECTION" ]] && [[ -f ~/.local/share/blesh/ble.sh ]] && source ~/.local/share/blesh/ble.sh --noattach
set -o vi

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
if [[ -f ~/.local/share/omarchy/default/bash/rc ]]; then
  source ~/.local/share/omarchy/default/bash/rc
else
  command -v starship &> /dev/null && eval "$(starship init bash)"
fi

[[ -f ~/.shared/env ]] && source ~/.shared/env
export GHOSTTY_SHELL_FEATURES="path,title"
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
