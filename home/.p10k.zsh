typeset -g _git_text=""
typeset -g _git_state=""
typeset -g _git_workspace=""
typeset -g _git_worker_init=""
typeset -g _git_root=""
typeset -g _git_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/p10k-git"
[[ -d $_git_cache_dir ]] || mkdir -p -- "$_git_cache_dir" 2>/dev/null

# Locate the repo root by walking up from $PWD in pure zsh (no forks).
# Handles worktrees/submodules where .git is a file. Result in $_git_root.
_git_find_root() {
  local dir=$PWD
  _git_root=""
  while :; do
    [[ -e $dir/.git ]] && { _git_root=$dir; return 0 }
    [[ $dir == / || -z $dir ]] && return 1
    dir=${dir:h}
  done
}

# Worker: runs git status asynchronously (receives dir as arg, no globals)
_git_async() {
  local dir=$1
  cd -q -- "$dir" || return 1

  local branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  [[ -z $branch ]] && branch=$(git rev-parse --short HEAD 2>/dev/null)
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

  # Persist so future shells can render the segment instantly (atomic write)
  local cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/p10k-git/${dir//\//%}"
  { print -r -- "${state}|${text}" > "${cache_file}.$$" &&
      mv -f -- "${cache_file}.$$" "$cache_file" } 2>/dev/null

  # Output: dir|state|text
  print -r -- "${dir}|${state}|${text}"
}

# Callback: update display variables and trigger redraw (only if changed)
_git_callback() {
  local job=$1 exit_code=$2 output=$3
  [[ $exit_code == 0 && -n $output ]] || return 0

  local dir=${output%%|*}
  local rest=${output#*|}
  local state=${rest%%|*}
  local text=${rest#*|}

  # Ignore late results for a repo we've navigated away from
  [[ $dir == "$_git_workspace" ]] || return 0
  # Only repaint when something actually changed — no flicker otherwise
  [[ $state == "$_git_state" && $text == "$_git_text" ]] && return 0

  _git_state=$state
  _git_text=$text
  p10k display -r
}

# Prompt segment
prompt_git() {
  # Initialize async worker on first use
  if [[ -z $_git_worker_init ]] && (( $+functions[async_init] )); then
    _git_worker_init=1
    async_init
    async_stop_worker _git_worker 2>/dev/null
    async_start_worker _git_worker
    async_unregister_callback _git_worker 2>/dev/null
    async_register_callback _git_worker _git_callback
  fi

  _git_find_root || { _git_workspace=""; return }

  # On workspace change (or new shell), seed from the persisted cache so the
  # first render already looks final; async refresh corrects it if stale.
  if [[ $_git_workspace != "$_git_root" ]]; then
    _git_workspace=$_git_root
    local cache_file=$_git_cache_dir/${_git_root//\//%}
    local cached=""
    [[ -r $cache_file ]] && cached=$(<$cache_file)
    if [[ -n $cached ]]; then
      _git_state=${cached%%|*}
      _git_text=${cached#*|}
    else
      # First visit ever: minimal branch display while async fills in
      _git_state="LOADING"
      _git_text=$(git symbolic-ref --short HEAD 2>/dev/null)
    fi
  fi

  (( $+functions[async_job] )) && async_job _git_worker _git_async "$_git_workspace"

  # Use -c conditions for dynamic state switching (from p10k issue #2471)
  p10k segment -s LOADING -c '${(M)_git_state:#LOADING}' -et '$_git_text'
  p10k segment -s CLEAN -c '${(M)_git_state:#CLEAN}' -et '$_git_text'
  p10k segment -s STAGED -c '${(M)_git_state:#STAGED}' -et '$_git_text'
  p10k segment -s MODIFIED -c '${(M)_git_state:#MODIFIED}' -et '$_git_text'
}

# Bake the last known git segment into p10k's per-directory instant prompt so
# it's visible from the very first frame instead of popping in after zshrc
# loads. Captured literally at dump time (hermetic); async corrects it later.
instant_prompt_git() {
  [[ -n $_git_state && -n $_git_text ]] || return
  p10k segment -s "$_git_state" -t "${_git_text//\%/%%}"
}

# ============================================================================
# POWERLEVEL10K CONFIGURATION
# ============================================================================
POWERLEVEL9K_CHRUBY_SHOW_ENGINE=false
POWERLEVEL9K_GIT_CLEAN_BACKGROUND=2
POWERLEVEL9K_GIT_CLEAN_FOREGROUND=0
POWERLEVEL9K_GIT_CLEAN_VISUAL_IDENTIFIER_EXPANSION=$'\uF408 '
POWERLEVEL9K_GIT_LOADING_BACKGROUND=8
POWERLEVEL9K_GIT_LOADING_FOREGROUND=0
POWERLEVEL9K_GIT_LOADING_VISUAL_IDENTIFIER_EXPANSION=$'\uF408 '
POWERLEVEL9K_GIT_MODIFIED_BACKGROUND=3
POWERLEVEL9K_GIT_MODIFIED_FOREGROUND=0
POWERLEVEL9K_GIT_MODIFIED_VISUAL_IDENTIFIER_EXPANSION=$'\uF408 '
POWERLEVEL9K_GIT_STAGED_BACKGROUND=2
POWERLEVEL9K_GIT_STAGED_FOREGROUND=0
POWERLEVEL9K_GIT_STAGED_VISUAL_IDENTIFIER_EXPANSION=$'\uF408 '
POWERLEVEL9K_INSTANT_PROMPT="quiet"
POWERLEVEL9K_MODE='nerdfont-complete'
POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX_ICON=""
POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX_ICON="%(?:%{$fg_bold[green]%}➜ :%{$fg_bold[red]%}➜ )"
POWERLEVEL9K_NODE_ENV_ICON="\ue781"
POWERLEVEL9K_NODE_ICON="\ue781"
POWERLEVEL9K_NODE_VERSION_FOREGROUND=black
POWERLEVEL9K_NODE_VERSION_ICON="\ue781"
POWERLEVEL9K_NODE_VERSION_PROJECT_ONLY=true
POWERLEVEL9K_OS_ICON_BACKGROUND='none'
POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
POWERLEVEL9K_PROMPT_ON_NEWLINE=true
POWERLEVEL9K_PYENV_ICON="\uf81f"
POWERLEVEL9K_PYTHON_ICON="\uf81f"
POWERLEVEL9K_RBENV_ICON="\ue21e"
POWERLEVEL9K_RUBY_ICON="\ue21e"
POWERLEVEL9K_SHORTEN_DELIMITER=
POWERLEVEL9K_SHORTEN_DIR_LENGTH=4
POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
POWERLEVEL9K_TIME_FORMAT='%D{%H:%M}'
POWERLEVEL9K_USER_DEFAULT_BACKGROUND=yellow
POWERLEVEL9K_USER_DEFAULT_FOREGROUND=black
POWERLEVEL9K_VIRTUALENV_BACKGROUND=magenta
POWERLEVEL9K_VIRTUALENV_CONTENT_EXPANSION=$'\ue606 ${P9K_CONTENT}'
POWERLEVEL9K_VIRTUALENV_FOREGROUND=black
POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=true
POWERLEVEL9K_VIRTUALENV_SHOW_WITH_PYENV=true
POWERLEVEL9K_VIRTUALENV_VISUAL_IDENTIFIER_EXPANSION=""
POWERLEVEL9K_VI_MODE_BACKGROUND=green
POWERLEVEL9K_VI_MODE_FOREGROUND=black
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
