# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

. "$HOME/.local/share/../bin/env"

[[ -f ~/.local/share/blesh/ble.sh ]] && source ~/.local/share/blesh/ble.sh --noattach

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
[[ -f ~/.local/share/omarchy/default/bash/rc ]] && source ~/.local/share/omarchy/default/bash/rc

export EDITOR='nvim'
export FZF_ALT_C_OPTS="--preview='tree -L 1 {}'"
export FZF_CTRL_T_COMMAND="fd --type file --follow --hidden --exclude .git"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}' --bind 'enter:execute(tmux send-keys \"C-c\" \"Enter\" \"$EDITOR {+}\" \"Enter\")+abort' --multi"
export FZF_DEFAULT_COMMAND="rg --files --hidden"
export FZF_TMUX_OPTS='-p 80%,60%'
export GHOSTTY_SHELL_FEATURES="path,title"
export HIGHLIGHT_STYLE=base16/seti

if [ -n "$DESKTOP_SESSION" ]; then
  export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
  export SSH_ASKPASS="/usr/lib/seahorse/ssh-askpass"
  export SSH_ASKPASS_REQUIRE=prefer
fi
export PATH="$HOME/.cargo/bin:$PATH"

alias vi='nvim'
alias n='nvim'
alias main='git checkout main'
alias please='sudo $(fc -ln -1)'
alias weather='curl wttr.in'
alias mux='tmuxinator'
alias brighter='tinty apply base16-synth-midnight-dark'
alias dark='tinty apply base16-seti'
alias darker='tinty apply base16-3024'
alias light='tinty apply base16-solarized-light'
alias lighter='tinty apply base16-one-light'
alias frappe='tinty apply base16-catppuccin-frappe'
alias latte='tinty apply base16-catppuccin-latte'
alias macchiato='tinty apply base16-catppuccin-macchiato'
alias mocha='tinty apply base16-catppuccin-mocha'

set -o vi

[[ -f /usr/share/bash-preexec/bash-preexec.sh ]] && source /usr/share/bash-preexec/bash-preexec.sh

if command -v gh &> /dev/null; then
  eval "$(gh completion -s bash)"
fi
if command -v atuin &> /dev/null; then
  eval "$(atuin init bash --disable-up-arrow)"
fi
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init bash)"
fi
if command -v gt &> /dev/null; then
  eval "$(gt completion)"
fi
if command -v carapace &> /dev/null; then
  source <(carapace _carapace)
fi

[[ ${BLE_VERSION-} ]] && ble-attach

if [[ ${BLE_VERSION-} ]]; then
  ble-face -s auto_complete 'fg=240'

  ble-face -s filename_directory 'fg=111'
  ble-face -s filename_directory_sticky 'fg=111'
  ble-face -s cmdinfo_cd_cdpath 'fg=111'

  ble-bind -m auto_complete -f 'S-TAB' 'auto_complete/insert'
fi

[[ -f ~/.functions.bash ]] && source ~/.functions.bash
