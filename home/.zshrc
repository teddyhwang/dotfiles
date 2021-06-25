BASE16_SHELL="$HOME/.base16-manager/chriskempson/base16-shell/"
if [ ! -d $BASE16_SHELL ]; then
  BASE16_SHELL="$HOME/.local/share/base16-manager/chriskempson/base16-shell/"
fi
[ -n "$PS1" ] && [ -s "$BASE16_SHELL/profile_helper.sh" ] && eval "$("$BASE16_SHELL/profile_helper.sh")"
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
export EDITOR='nvim'
export FZF_ALT_C_OPTS="--preview='tree -L 1 {}'"
export FZF_CTRL_T_COMMAND="fd --type file --follow --hidden --exclude .git"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"
export FZF_DEFAULT_COMMAND="rg --files --hidden" # --no-ignore-vcs
export FZF_DEFAULT_OPTS='--height 30% --border'
export FZF_TMUX_OPTS='-d 40%'
export HIGHLIGHT_STYLE=base16/seti
export LS_COLORS="$(vivid generate molokai)"
export NVM_DIR="$HOME/.nvm"

alias brighter='b16m set synth-midnight-dark'
alias dark='b16m set seti'
alias darker='b16m set 3024'
alias light='b16m set solarized-light'
alias lighter='b16m set one-light'
alias mux="tmuxinator"
alias ng="npm list -g --depth=0 2>/dev/null"
alias nl="npm list --depth=0 2>/dev/null"
alias ping='prettyping --nolegend'
alias please='sudo $(fc -ln -1)'
alias rake="noglob rake"
alias random='b16m set-random'
alias vi='nvim'
alias weather='curl wttr.in'

DISABLE_AUTO_UPDATE=true
DISABLE_UPDATE_PROMPT=true
POWERLEVEL9K_CHRUBY_SHOW_ENGINE=false
POWERLEVEL9K_INSTANT_PROMPT="verbose"
POWERLEVEL9K_MODE='nerdfont-complete'
POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX_ICON=""
POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX_ICON="%(?:%{$fg_bold[green]%}➜ :%{$fg_bold[red]%}➜ )"
POWERLEVEL9K_NODE_ENV_ICON="\ue781"
POWERLEVEL9K_NODE_ICON="\ue781"
POWERLEVEL9K_NODE_VERSION_FOREGROUND=black
POWERLEVEL9K_NODE_VERSION_ICON="\ue781"
POWERLEVEL9K_NODE_VERSION_PROJECT_ONLY=true
POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
POWERLEVEL9K_PROMPT_ON_NEWLINE=true
POWERLEVEL9K_PYENV_ICON="\uf81f"
POWERLEVEL9K_PYTHON_ICON="\uf81f"
POWERLEVEL9K_RBENV_ICON="\ue21e"
POWERLEVEL9K_RUBY_ICON="\ue21e"
POWERLEVEL9K_TIME_FORMAT='%D{%H:%M}'
POWERLEVEL9K_USER_DEFAULT_BACKGROUND=yellow
POWERLEVEL9K_USER_DEFAULT_FOREGROUND=black
POWERLEVEL9K_VCS_GIT_GITHUB_ICON='\uF408 '
POWERLEVEL9K_VCS_GIT_HOOKS=(vcs-detect-changes)
POWERLEVEL9K_VCS_GIT_ICON='\uF408 '
POWERLEVEL9K_VI_MODE_BACKGROUND=green
POWERLEVEL9K_VI_MODE_FOREGROUND=black
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  os_icon
  user
  node_version
  chruby
  dir_writable
  dir
  vcs
)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  status
  command_execution_time
  root_indicator
  background_jobs
  time
  disk_usage
  ram
  vi_mode
)
VI_MODE_SET_CURSOR=true
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC='true'
ZSH_DISABLE_COMPFIX=true
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  colorize
  git
  history-substring-search
  man
  node
  npm
  rails
  rake-fast
  ripgrep
  ruby
  vi-mode
  z
  zsh-autosuggestions
  zsh-completions
  zsh-syntax-highlighting
)
fpath=(~/.zsh.d/ $fpath)

[ -f $HOME/.oh-my-zsh/oh-my-zsh.sh ] && source $HOME/.oh-my-zsh/oh-my-zsh.sh
[ -f /usr/local/share/chruby/auto.sh ] && source /usr/local/share/chruby/auto.sh
[ -f /usr/local/share/chruby/chruby.sh ] && source /usr/local/share/chruby/chruby.sh
[ -f ~/.fzf.colors ] && source ~/.fzf.colors
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh
[ -f /usr/local/bin/virtualenvwrapper.sh ] && source /usr/local/bin/virtualenvwrapper.sh
[ -f /opt/homebrew/bin/virtualenvwrapper.sh ] && source /opt/homebrew/bin/virtualenvwrapper.sh
[ -f ~/.bin/tmuxinator.zsh ] && source ~/.bin/tmuxinator.zsh
[ -f /opt/homebrew/opt/chruby/share/chruby/chruby.sh ] && source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
[ -f ~/.nix-profile/etc/profile.d/nix.sh ] && source ~/.nix-profile/etc/profile.d/nix.sh
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
# https://nathanmlong.com/2015/01/optimizing-chruby-for-zsh/
if [ -f /opt/homebrew/opt/chruby/share/chruby/auto.sh ]; then
  unset RUBY_AUTO_VERSION

  function chruby_auto() {
    local dir="$PWD/" version

    until [[ -z "$dir" ]]; do
      dir="${dir%/*}"

      if { read -r version <"$dir/.ruby-version"; } 2>/dev/null || [[ -n "$version" ]]; then
        if [[ "$version" == "$RUBY_AUTO_VERSION" ]]; then return
        else
          RUBY_AUTO_VERSION="$version"
          chruby "$version"
          return $?
        fi
      fi
    done

    if [[ -n "$RUBY_AUTO_VERSION" ]]; then
      chruby_reset
      unset RUBY_AUTO_VERSION
    fi
  }

  chpwd_functions+=("chruby_auto")
  chruby_auto
fi

autoload -U compinit && compinit
setopt AUTO_PUSHD
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' cache-path ~/.zsh/cache
zstyle ':completion:*' use-cache on
zstyle ':completion:*:directory-stack' list-colors '=(#b) #([0-9]#)*( *)==95=38;5;12'

if [[ -n "$TMUX" ]]; then
  bindkey '^A' beginning-of-line
  bindkey '^E' end-of-line
fi
bindkey '^[[Z' autosuggest-accept
bindkey '^f' fzf-cd-widget
bindkey '^j' history-substring-search-down
bindkey '^k' history-substring-search-up
bindkey -M vicmd "j" down-line-or-beginning-search
bindkey -M vicmd "k" up-line-or-beginning-search

if command -v gh &> /dev/null; then
  eval "$(gh completion -s zsh)"
fi

function upgrade_custom_oh_my_zsh() {
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

function upgrade_all_oh_my_zsh() {
  upgrade_custom_oh_my_zsh 'plugins'
  upgrade_custom_oh_my_zsh 'themes'
  omz update
}

function b16m() {
  base16-manager $@
  source $HOME/.fzf.colors
}

function ranger() {
  local IFS=$'\t\n'
  local tempfile="$(mktemp -t tmp.XXXXXX)"
  local ranger_cmd=(
    command
    ranger
    --cmd="map Q chain shell echo %d > "$tempfile"; quitall"
  )
  
  ${ranger_cmd[@]} "$@"
  if [[ -f "$tempfile" ]] && [[ "$(cat -- "$tempfile")" != "$(echo -n `pwd`)" ]]; then
    cd -- "$(cat "$tempfile")" || return
  fi
  command rm -f -- "$tempfile" 2>/dev/null
}

function lg() {
  export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir

  lazygit "$@"

  if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
    cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
    rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
  fi
}
