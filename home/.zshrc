if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

[[ -f "$HOME/.local/share/../bin/env" ]] && . "$HOME/.local/share/../bin/env"

[[ -f ~/.shared/env ]] && source ~/.shared/env

DISABLE_AUTO_UPDATE=true
DISABLE_UPDATE_PROMPT=true
VI_MODE_SET_CURSOR=true
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC='true'
ZSH_DISABLE_COMPFIX=true
ZSH_THEME="powerlevel10k/powerlevel10k"

[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

plugins=(
  colorize
  gitfast
  man
  rake-fast
  vi-mode
  zsh-autosuggestions
  zsh-completions
  zsh-syntax-highlighting
)

[[ -f ~/.oh-my-zsh/oh-my-zsh.sh ]] && source ~/.oh-my-zsh/oh-my-zsh.sh
if [[ -f /opt/homebrew/opt/chruby/share/chruby/chruby.sh ]]; then
  source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
  source /opt/homebrew/opt/chruby/share/chruby/auto.sh
  chpwd_functions+=("chruby_auto")
fi
if [[ -f /usr/local/opt/chruby/share/chruby/chruby.sh ]]; then
  source /usr/local/opt/chruby/share/chruby/chruby.sh
  source /usr/local/opt/chruby/share/chruby/auto.sh
  chpwd_functions+=("chruby_auto")
fi
if [[ -f /opt/dev/dev.sh ]]; then
  source /opt/dev/dev.sh
  [[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }
fi
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

autoload -U compinit && compinit
setopt AUTO_PUSHD

zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' cache-path ~/.zsh/cache
zstyle ':completion:*' use-cache on
zstyle ':completion:*:directory-stack' list-colors '=(#b) #([0-9]#)*( *)==95=38;5;12'
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-separator ''
zstyle ':completion:*:descriptions' format '%F{green}%d%f'
zstyle ':completion:*:warnings' format '%F{red}no matches found%f'

zstyle ':completion:*' list-colors '=*=38;5;14' '=*=38;5;15'
zstyle ':completion:*:default' list-colors '=*=38;5;14' '=*=38;5;15'
zstyle ':completion:*:corrections' list-colors '=*=38;5;14' '=*=38;5;15'
zstyle ':completion:*:descriptions' list-colors '=*=38;5;14' '=*=38;5;15'

zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

bindkey '^[[Z' autosuggest-accept
bindkey '^f' fzf-cd-widget

[[ -f ~/.shared/aliases ]] && source ~/.shared/aliases
[[ -f ~/.shared/init ]] && source ~/.shared/init
[[ -f ~/.claude/local/claude ]] && alias claude="~/.claude/local/claude"

# Added by tec agent
[[ -x /Users/teddyhwang/.local/state/tec/profiles/base/current/global/init ]] && eval "$(/Users/teddyhwang/.local/state/tec/profiles/base/current/global/init zsh)"

# Fix fzf ctrl-t not working when entering shadowenv environment
__fzf_rebind_hook() {
  if [[ "$1" == "precmd" ]]; then
    if [[ "${__shadowenv_data:-}" != "${__fzf_last_shadowenv_data:-}" ]]; then
      __fzf_last_shadowenv_data="${__shadowenv_data:-}"

      [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
    fi
  fi
}

if typeset -f hookbook_add_hook > /dev/null; then
  hookbook_add_hook __fzf_rebind_hook
fi

[[ -f ~/.shared/functions ]] && . ~/.shared/functions
