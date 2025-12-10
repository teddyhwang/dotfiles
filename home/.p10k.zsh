typeset -g _git_text=""
typeset -g _git_state="LOADING"
typeset -g _git_workspace=""

# Worker: runs git status asynchronously (receives dir as arg, no globals)
_git_async() {
  local dir=$1
  cd "$dir" || return 1

  local branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  [[ -z $branch ]] && return 1

  local staged=0 unstaged=0 untracked=0
  local line
  while IFS= read -r line; do
    [[ $line[1] == [MADRC] ]] && ((staged++))
    [[ $line[2] == [MD] ]] && ((unstaged++))
    [[ $line[1] == "?" ]] && ((untracked++))
  done < <(git status --porcelain 2>/dev/null)

  # Build display text with nerd font icons and counts
  # Only show branch icon if not on main/master
  local text=""
  if [[ $branch != main && $branch != master ]]; then
    text=$'\uF126 '"$branch"
  else
    text="$branch"
  fi
  (( staged > 0 )) && text+=$' \uF055 '"$staged"
  (( unstaged > 0 )) && text+=$' \uF06A '"$unstaged"
  (( untracked > 0 )) && text+=$' \uF059 '"$untracked"

  # Output: state|text
  # CLEAN: no changes
  # STAGED: only staged changes (green with icon)
  # MODIFIED: unstaged changes (yellow)
  local state="CLEAN"
  (( staged > 0 && unstaged == 0 )) && state="STAGED"
  (( unstaged > 0 )) && state="MODIFIED"
  echo "${state}|${text}"
}

# Callback: update display variables and trigger redraw
_git_callback() {
  local job=$1 exit_code=$2 output=$3

  if [[ $exit_code == 0 && -n $output ]]; then
    _git_state=${output%%|*}
    _git_text=${output#*|}
  fi

  p10k display -r
}

# Prompt segment
prompt_git() {
  # Initialize async worker on first use
  if (( $+functions[async_init] )) && [[ -z $_git_workspace ]]; then
    async_init
    async_stop_worker _git_worker 2>/dev/null
    async_start_worker _git_worker
    async_unregister_callback _git_worker 2>/dev/null
    async_register_callback _git_worker _git_callback
  fi

  local workspace
  workspace=$(git rev-parse --show-toplevel 2>/dev/null) || return

  # Reset to loading on workspace change
  if [[ $_git_workspace != "$workspace" ]]; then
    _git_workspace="$workspace"
    _git_text=$(git symbolic-ref --short HEAD 2>/dev/null)
  fi

  # Always start in loading state until async completes
  _git_state="LOADING"

  async_job _git_worker _git_async "$workspace"

  # Use -c conditions for dynamic state switching (from p10k issue #2471)
  p10k segment -s LOADING -c '${(M)_git_state:#LOADING}' -et '$_git_text'
  p10k segment -s CLEAN -c '${(M)_git_state:#CLEAN}' -et '$_git_text'
  p10k segment -s STAGED -c '${(M)_git_state:#STAGED}' -et '$_git_text'
  p10k segment -s MODIFIED -c '${(M)_git_state:#MODIFIED}' -et '$_git_text'
}

# ============================================================================
# POWERLEVEL10K CONFIGURATION
# ============================================================================
POWERLEVEL9K_CHRUBY_SHOW_ENGINE=false
POWERLEVEL9K_GIT_LOADING_BACKGROUND=8
POWERLEVEL9K_GIT_LOADING_FOREGROUND=0
POWERLEVEL9K_GIT_LOADING_VISUAL_IDENTIFIER_EXPANSION=$'\uF408 '
POWERLEVEL9K_GIT_CLEAN_BACKGROUND=2
POWERLEVEL9K_GIT_CLEAN_FOREGROUND=0
POWERLEVEL9K_GIT_CLEAN_VISUAL_IDENTIFIER_EXPANSION=$'\uF408 '
POWERLEVEL9K_GIT_STAGED_BACKGROUND=2
POWERLEVEL9K_GIT_STAGED_FOREGROUND=0
POWERLEVEL9K_GIT_STAGED_VISUAL_IDENTIFIER_EXPANSION=$'\uF408 '
POWERLEVEL9K_GIT_MODIFIED_BACKGROUND=3
POWERLEVEL9K_GIT_MODIFIED_FOREGROUND=0
POWERLEVEL9K_GIT_MODIFIED_VISUAL_IDENTIFIER_EXPANSION=$'\uF408 '
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
POWERLEVEL9K_VI_MODE_BACKGROUND=green
POWERLEVEL9K_VI_MODE_FOREGROUND=black
POWERLEVEL9K_VIRTUALENV_BACKGROUND=magenta
POWERLEVEL9K_VIRTUALENV_FOREGROUND=black
POWERLEVEL9K_VIRTUALENV_VISUAL_IDENTIFIER_EXPANSION=""
POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=true
POWERLEVEL9K_VIRTUALENV_SHOW_WITH_PYENV=true
POWERLEVEL9K_VIRTUALENV_CONTENT_EXPANSION=$'\ue606 ${P9K_CONTENT}'
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  os_icon
  user
  ssh
  node_version
  chruby
  virtualenv
  dir_writable
  dir
  git
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
