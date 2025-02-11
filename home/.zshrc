if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

[[ -f ~/.zprofile ]] && source ~/.zprofile
typeset -U PATH path

export BASE16_THEME_DEFAULT="seti"
export EDITOR='nvim'
export FZF_ALT_C_OPTS="--preview='tree -L 1 {}'"
export FZF_CTRL_T_COMMAND="fd --type file --follow --hidden --exclude .git"
export FZF_CTRL_T_OPTS="--preview 'bat --theme=base16-seti --style=numbers --color=always --line-range :500 {}'"
export FZF_DEFAULT_COMMAND="rg --files --hidden"
export FZF_DEFAULT_OPTS="--border"
export FZF_TMUX_OPTS='-d 40%'
export HIGHLIGHT_STYLE=base16/seti
export TERM="xterm-256color"
export XDG_CONFIG_HOME="$HOME/.config"
if [ $SPIN ]; then
  source ~/.spin.zsh
fi

DISABLE_AUTO_UPDATE=true
DISABLE_UPDATE_PROMPT=true
VI_MODE_SET_CURSOR=true
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC='true'
ZSH_DISABLE_COMPFIX=true
ZSH_THEME="powerlevel10k/powerlevel10k"

source ~/.p10k.zsh

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

[ -f ~/.oh-my-zsh/oh-my-zsh.sh ] && source ~/.oh-my-zsh/oh-my-zsh.sh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
if [ -f /opt/homebrew/opt/chruby/share/chruby/chruby.sh ]; then
  source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
  source /opt/homebrew/opt/chruby/share/chruby/auto.sh
  chpwd_functions+=("chruby_auto")
fi
if [ -f /usr/local/opt/chruby/share/chruby/chruby.sh ]; then
  source /usr/local/opt/chruby/share/chruby/chruby.sh
  source /usr/local/opt/chruby/share/chruby/auto.sh
  chpwd_functions+=("chruby_auto")
fi
if [ -f /opt/dev/dev.sh ]; then
  source /opt/dev/dev.sh
  [[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }
fi
[[ -x /usr/local/bin/brew ]] && eval $(/usr/local/bin/brew shellenv)
[[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)

autoload -U compinit && compinit
setopt AUTO_PUSHD

zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' cache-path ~/.zsh/cache
zstyle ':completion:*' use-cache on
zstyle ':completion:*:directory-stack' list-colors '=(#b) #([0-9]#)*( *)==95=38;5;12'
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions' format '%F{green}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- no matches found --%f'

bindkey '^[[Z' autosuggest-accept
bindkey '^f' fzf-cd-widget

alias brighter='tinty apply base16-synth-midnight-dark'
alias dark='tinty apply base16-seti'
alias darker='tinty apply base16-3024'
alias light='tinty apply base16-solarized-light'
alias lighter='tinty apply base16-one-light'
alias mocha='tinty apply base16-catppuccin-mocha'

alias gpgstart='gpgconf --launch gpg-agent'
alias ls='lsd'
alias main='git checkout main'
alias mux="tmuxinator"
alias ng="npm list -g --depth=0 2>/dev/null"
alias nl="npm list --depth=0 2>/dev/null"
alias nvs="nvim -S Session.vim"
alias ping='prettyping --nolegend'
alias please='sudo $(fc -ln -1)'
alias rake="noglob rake"
alias vi='nvim'
alias weather='curl wttr.in'

update_custom_oh_my_zsh() {
  example='example'
  custom_type=$1
  for custom_plugin_or_theme in $ZSH/custom/$custom_type/*; do
    if test "${custom_plugin_or_theme#*$example}" = "$custom_plugin_or_theme"
    then
      printf "Upgrading $custom_plugin_or_theme...\n"
      cd $custom_plugin_or_theme && git pull --stat && cd -
    fi
  done
}

update() {
  update_custom_oh_my_zsh 'plugins'
  update_custom_oh_my_zsh 'themes'
  omz update
  tinty update
}

lg() {
  export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir

  lazygit "$@"

  if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
    cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
    rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
  fi
}

ssh() {
  case $1 in
    mini)
      command ssh teddys-mac-mini.local
      ;;
    work)
      command ssh teddys-shopify-macBook-pro.local
      ;;
    mbp)
      command ssh teddys-macbook-pro.local
      ;;
    nicole)
      command ssh nicolepaik@nicoles-macbook-air.local
      ;;
    spin)
      command ssh $(spin show --output fqdn)
      ;;
    *)
      command ssh $@
      ;;
  esac
}

tmux() {
  case $1 in
    start)
      command tmux new-session -d -s $2
      command tmux new-window -n Terminal
      command tmux kill-window -t 0
      command tmux new-window -d -n Editor
      command tmux new-window -d -n Server
      command tmux select-window -t 0
      ;;
    *)
      command tmux $@
      ;;
  esac
}

tig() {
  command tig "$@" --pretty=fuller
}

y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

killport() {
  lsof -i tcp:$1 | awk 'NR!=1 {print $2}' | xargs kill -9
}

branch() {
  if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git for-each-ref --color --sort=-committerdate \
      refs/heads/ \
      --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) | (%(color:green)%(committerdate:relative)%(color:reset)) %(color:bold)%(authorname)%(color:reset) - %(contents:subject)' | \
      fzf --ansi | \
      cut -f2 -d'*' | \
      cut -f1 -d'|' | \
      xargs)

    if [ ! -z "$branch" ] ; then
      git checkout "$branch"
    fi
  else
    echo 'ERROR: Not a git repository'
  fi
}

cob() {
  if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --color --sort=-committerdate \
      --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) | (%(color:green)%(committerdate:relative)%(color:reset)) %(color:bold)%(authorname)%(color:reset) - %(contents:subject)' -r | \
      fzf --ansi | \
      sed "s/origin\///g" | \
      cut -f1 -d'|' | \
      xargs)

    if [ ! -z "$branch" ] ; then
      git checkout "$branch"
    fi
  else
    echo 'ERROR: Not a git repository'
  fi
}

upstream() {
  branch=$(git rev-parse --abbrev-ref HEAD)
  if [ ! -z "$branch" ] ; then
    git branch --set-upstream-to=origin/$branch $branch
  fi
}

tinty_source_shell_theme() {
  newer_file=$(mktemp)
  tinty $@
  subcommand="$1"

  if [ "$subcommand" = "apply" ] || [ "$subcommand" = "init" ]; then
    tinty_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tinted-theming/tinty"

    while read -r script; do
      . "$script"
    done < <(find "$tinty_data_dir" -maxdepth 1 -type f -name "*.sh" -newer "$newer_file")

    unset tinty_data_dir
  fi

  unset subcommand
}

theme () {
  tinty_source_shell_theme apply $(tinty list | fzf)
}

if [ -n "$(command -v 'tinty')" ]; then
  if [[ $- == *i* ]] && [[ -z "$FLOATERM" ]]; then
    eval "$(tinty generate-completion zsh)"
    alias tinty=tinty_source_shell_theme
    compdef tinty_source_shell_theme=tinty

    tinty_source_shell_theme "init" > /dev/null
  fi
fi

if command -v gh &> /dev/null; then
  eval "$(gh completion -s zsh)"
fi
if command -v atuin &> /dev/null; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi
