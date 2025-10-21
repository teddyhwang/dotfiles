if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

[[ -f ~/.zprofile ]] && source ~/.zprofile

export BASE16_THEME_DEFAULT="seti"
export EDITOR='nvim'
export FZF_ALT_C_OPTS="--preview='tree -L 1 {}'"
export FZF_CTRL_T_COMMAND="fd --type file --follow --hidden --exclude .git"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}' --bind 'enter:execute(tmux send-keys \"C-c\" \"Enter\" \"$EDITOR {+}\" \"Enter\")+abort' --multi"
export FZF_DEFAULT_COMMAND="rg --files --hidden"
export FZF_TMUX_OPTS='-p 80%,60%'
export HIGHLIGHT_STYLE=base16/seti
export TERM="xterm-256color"
export XDG_CONFIG_HOME="$HOME/.config"
if command -v vivid &> /dev/null; then
  export LS_COLORS=$(vivid generate molokai)
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
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

autoload -U compinit && compinit
setopt AUTO_PUSHD

if command -v carapace &> /dev/null; then
  source <(carapace _carapace)
fi

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

alias brighter='tinty apply base16-synth-midnight-dark'
alias dark='tinty apply base16-seti'
alias darker='tinty apply base16-3024'
alias light='tinty apply base16-solarized-light'
alias lighter='tinty apply base16-one-light'
alias frappe='tinty apply base16-catppuccin-frappe'
alias latte='tinty apply base16-catppuccin-latte'
alias macchiato='tinty apply base16-catppuccin-macchiato'
alias mocha='tinty apply base16-catppuccin-mocha'

alias gpgstart='gpgconf --launch gpg-agent'
alias ls='lsd'
alias main='git checkout main'
alias mux="tmuxinator"
alias ng="npm list -g --depth=0 2>/dev/null"
alias nl="npm list --depth=0 2>/dev/null"
alias ping='prettyping --nolegend'
alias please='sudo $(fc -ln -1)'
alias rake="noglob rake"
alias n="nvim"
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
      if [ -n "$TMUX" ]; then
        command tmux new-session -d -s $2
        command tmux rename-window -t $2:0 Terminal
        command tmux new-window -t $2 -n Editor
        command tmux new-window -t $2 -n Server
        command tmux select-window -t $2:0
        command tmux switch-client -t $2
      else
        command tmux new-session -s $2
        command tmux rename-window -t $2:0 Terminal
        command tmux new-window -t $2 -n Editor
        command tmux new-window -t $2 -n Server
        command tmux select-window -t $2:0
      fi
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
  tinty_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tinted-theming/tinty"

  if [ "$1" = "init" ]; then
    tinty $@
    while read -r script; do
      . "$script"
    done < <(find "$tinty_data_dir" -maxdepth 1 -name "*.sh")
  elif [ "$1" = "apply" ]; then
    newer_file=$(mktemp)
    tinty $@
    while read -r script; do
      . "$script"
    done < <(find "$tinty_data_dir" -maxdepth 1 -name "*.sh" -newer "$newer_file")
    rm -f "$newer_file"
  else
    tinty $@
  fi

  unset tinty_data_dir
}

theme () {
  tinty_source_shell_theme apply $(tinty list | fzf)
}

if [ -n "$(command -v 'tinty')" ]; then
  if [[ $- == *i* ]] && [[ -z "$FLOATERM" ]] && [[ -z "$NVIM" ]]; then
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
if command -v gt &> /dev/null; then
  eval "$(gt completion)"
fi

[ -f ~/.claude/local/claude ] && alias claude="~/.claude/local/claude"

# Added by tec agent
[[ -x /Users/teddyhwang/.local/state/tec/profiles/base/current/global/init ]] && eval "$(/Users/teddyhwang/.local/state/tec/profiles/base/current/global/init zsh)"

# Fix fzf ctrl-t not working when entering shadowenv environment
__fzf_rebind_hook() {
  if [[ "$1" == "precmd" ]]; then
    if [[ "${__shadowenv_data:-}" != "${__fzf_last_shadowenv_data:-}" ]]; then
      __fzf_last_shadowenv_data="${__shadowenv_data:-}"

      [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
    fi
  fi
}

if typeset -f hookbook_add_hook > /dev/null; then
  hookbook_add_hook __fzf_rebind_hook
fi
