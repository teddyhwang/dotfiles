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
ZVM_INIT_MODE=sourcing

zvm_after_init() {
  [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
  [[ -f ~/.cache/shared_init_cache.zsh ]] && source ~/.cache/shared_init_cache.zsh
  bindkey '^[[Z' autosuggest-accept
  zicdreplay
}

zinit ice wait lucid
zinit light jeffreytse/zsh-vi-mode
zvm_after_init_commands+=('
  function zvm_vi_yank() {
    zvm_yank
    printf %s "${CUTBUFFER}" | pbcopy
    zvm_exit_visual_mode
  }
')

zinit ice wait lucid atload'_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions

zinit ice wait lucid
zinit light zsh-users/zsh-syntax-highlighting

zinit ice wait lucid
zinit light zsh-users/zsh-completions

zinit light mafredri/zsh-async

fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit
# Run a full compinit at most once per day; otherwise use cached dump.
# NOTE: the (#qN.mh+24) glob qualifier requires extended_glob — without it the
# test always evaluates to true and full compinit runs on every shell startup
# (~437ms in the shopify monorepo). Scope the option locally so we don't leak it.
() {
  emulate -L zsh
  setopt extended_glob
  local zcd=${ZDOTDIR:-$HOME}/.zcompdump
  if [[ -n $zcd(#qN.mh+24) ]]; then
    compinit -i -d $zcd
  else
    compinit -C -d $zcd
  fi
}
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

# Added by tec agent
if [[ -x /Users/teddyhwang/.local/state/tec/profiles/base/current/global/init ]]; then
  _tec_init="/Users/teddyhwang/.local/state/tec/profiles/base/current/global/init"
  _tec_cache="$HOME/.cache/tec_init_cache.zsh"
  if [[ ! -f "$_tec_cache" ]] || [[ "$_tec_init" -nt "$_tec_cache" ]]; then
    "$_tec_init" zsh >"$_tec_cache" 2>/dev/null
    wcd --init zsh >>"$_tec_cache" 2>/dev/null
  fi
  . "$_tec_cache"

  # tec's generated init only adds its bootstrap paths when they are missing.
  # Long-lived shells/tmux can inherit stale copies after Homebrew, so force the
  # canonical tec profile paths back ahead of Homebrew for dev's PATH-order check.
  for _tec_path in \
    "$HOME/.local/state/tec/profiles/base/current/global/bin" \
    "$HOME/.local/state/nix/profiles/tec/bin"; do
    [[ -d "$_tec_path" ]] && path=("$_tec_path" ${path:#$_tec_path})
  done

  unset _tec_init _tec_cache _tec_path
  [[ -f ~/.shared/shopify ]] && . ~/.shared/shopify
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
    local dir="$PWD/" rbv
    while [[ -n "$dir" ]]; do
      dir="${dir%/*}"
      if [[ -f "$dir/.ruby-version" ]]; then
        RUBY_ENGINE=ruby
        # Read .ruby-version directly instead of forking `ruby -e ...` (saves
        # ~40ms warm / ~130ms cold per cd into a Ruby project, e.g. shopify).
        rbv="$(<"$dir/.ruby-version")"
        rbv="${rbv//[[:space:]]/}"
        rbv="${rbv#ruby-}"
        RUBY_VERSION="${rbv:-unknown}"
        return
      fi
    done
  fi
}

__sync_tmux_ssh_env_hook() {
  [[ "$1" == "precmd" ]] || return
  [[ -n "$TMUX" ]] || return
  (( $+commands[tmux] )) || return

  # One tmux call instead of four — saves ~20ms per precmd.
  local env_data line
  env_data=$(tmux show-environment -g 2>/dev/null) || return
  while IFS= read -r line; do
    case "$line" in
      SSH_AUTH_SOCK=*|SSH_CONNECTION=*|SSH_CLIENT=*|SSH_TTY=*)
        export "$line"
        ;;
      -SSH_AUTH_SOCK|-SSH_CONNECTION|-SSH_CLIENT|-SSH_TTY)
        unset "${line#-}"
        ;;
    esac
  done <<< "$env_data"
}

if typeset -f hookbook_add_hook > /dev/null; then
  hookbook_add_hook __fzf_rebind_hook
  hookbook_add_hook __ruby_env_hook
  hookbook_add_hook __sync_tmux_ssh_env_hook
fi

if (( $+commands[shadowenv] )); then
  shadowenv hook --force 2>/dev/null | source /dev/stdin
  unset __shadowenv_force_run
fi
__ruby_env_hook precmd
__sync_tmux_ssh_env_hook precmd

tinty_source_shell_theme() {
  tinty_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tinted-theming/tinty"

  if [ "$1" = "init" ]; then
    command tinty $@
    while read -r script; do
      . "$script"
    done < <(find "$tinty_data_dir" -maxdepth 1 -name "*.sh")
  elif [ "$1" = "apply" ]; then
    newer_file=$(mktemp)
    command tinty $@
    while read -r script; do
      . "$script"
    done < <(find "$tinty_data_dir" -maxdepth 1 -name "*.sh" -newer "$newer_file")
    rm -f "$newer_file"
  else
    command tinty $@
  fi

  _tinty_rebuild_cache 2>/dev/null

  unset tinty_data_dir
}

_tinty_rebuild_cache() {
  local cache="$HOME/.cache/tinty_init_cache.zsh"
  local data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tinted-theming/tinty"
  : >| "$cache"
  for script in "$data_dir"/*.sh(N); do
    printf '. %q\n' "$script" >> "$cache"
  done
  zcompile "$cache" 2>/dev/null
}

if (( $+commands[tinty] )); then
  alias tinty=tinty_source_shell_theme
  () {
    emulate -L zsh
    setopt extended_glob
    local cache="$HOME/.cache/tinty_init_cache.zsh"
    local data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tinted-theming/tinty"
    local newer=($data_dir/*.sh(Ne:'[[ $REPLY -nt $cache ]]':))
    if [[ -f $cache && ${#newer} -eq 0 ]]; then
      source $cache
    else
      tinty_source_shell_theme "init" &> /dev/null
    fi
  }
fi

() {
  emulate -L zsh
  setopt extended_glob
  local f
  for f in \
    "${HOME}/.zshrc" \
    "${HOME}/.p10k.zsh" \
    "${HOME}/.cache/shared_init_cache.zsh" \
    "${HOME}/.cache/tec_init_cache.zsh" \
    "${HOME}/.cache/tinty_init_cache.zsh"; do
    [[ -f $f && ( ! -f ${f}.zwc || $f -nt ${f}.zwc ) ]] && zcompile $f 2>/dev/null
  done
}
