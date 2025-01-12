function prompt_git_info() {
  if git rev-parse --git-dir &> /dev/null; then
    if [[ $(git config --get core.sparsecheckout) == "true" || $(git config --get core.repositoryformatversion) == "1" ]]; then
      POWERLEVEL9K_DISABLE_GITSTATUS=true
    else
      POWERLEVEL9K_DISABLE_GITSTATUS=false
    fi
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd prompt_git_info

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
  ssh
  node_version
  chruby
  pyenv
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
