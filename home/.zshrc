if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

[[ -f "$HOME/.local/share/../bin/env" ]] && . "$HOME/.local/share/../bin/env"

[[ -f ~/.shared/env ]] && source ~/.shared/env
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

zinit ice depth=1
zinit light romkatv/powerlevel10k

[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC='true'

zvm_after_init() {
  [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
  [[ -f ~/.cache/shared_init_cache.zsh ]] && source ~/.cache/shared_init_cache.zsh
  bindkey '^[[Z' autosuggest-accept
  zicdreplay
}

zinit ice wait lucid
zinit light jeffreytse/zsh-vi-mode

zinit ice wait lucid atload'_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions

zinit ice wait lucid
zinit light zsh-users/zsh-syntax-highlighting

zinit ice wait lucid
zinit light zsh-users/zsh-completions

zinit light mafredri/zsh-async

fpath=(~/.zsh/completions $fpath)
autoload -U compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi
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
[[ -f ~/.shared/functions ]] && . ~/.shared/functions

if [[ -x "$HOME/.local/state/tec/profiles/base/current/global/init" ]]; then
  eval "$("$HOME/.local/state/tec/profiles/base/current/global/init" zsh)"
  eval "$(wcd --init zsh)"
else
  for _chruby_dir in /opt/homebrew/opt/chruby/share/chruby /usr/local/opt/chruby/share/chruby; do
    if [[ -f "$_chruby_dir/chruby.sh" ]]; then
      source "$_chruby_dir/chruby.sh"
      source "$_chruby_dir/auto.sh"
      chpwd_functions+=("chruby_auto")
      break
    fi
  done
  unset _chruby_dir
fi

__fzf_rebind_hook() {
  if [[ "$1" == "precmd" ]]; then
    if [[ "${__shadowenv_data:-}" != "${__fzf_last_shadowenv_data:-}" ]]; then
      __fzf_last_shadowenv_data="${__shadowenv_data:-}"
      zvm_after_init
    fi
  fi
}

__ruby_env_hook() {
  if [[ "$1" != "precmd" || "$__ruby_env_last_pwd" == "$PWD" ]]; then return; fi
  __ruby_env_last_pwd="$PWD"
  if [[ -z "$RUBY_ENGINE" ]] && (( $+commands[ruby] )); then
    local dir="$PWD/"
    while [[ -n "$dir" ]]; do
      dir="${dir%/*}"
      if [[ -f "$dir/.ruby-version" ]]; then
        RUBY_ENGINE=ruby
        RUBY_VERSION="${$(ruby -e 'print RUBY_VERSION' 2>/dev/null):-unknown}"
        return
      fi
    done
  fi
}

if typeset -f hookbook_add_hook > /dev/null; then
  hookbook_add_hook __fzf_rebind_hook
  hookbook_add_hook __ruby_env_hook
fi

if (( $+commands[shadowenv] )); then
  shadowenv hook --force 2>/dev/null | source /dev/stdin
  unset __shadowenv_force_run
fi
__ruby_env_hook precmd
