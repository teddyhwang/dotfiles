# ============================================================================
# SPARSE GIT SEGMENT FOR WORLD REPO
# gitstatus doesn't work with sparse checkouts due to libgit2 limitations
# Simple async with file cache - updates on next prompt
# ============================================================================

typeset -gA _sparse_git_cache=()

function prompt_sparse_git() {
  [[ $PWD != */world/* ]] && return

  local branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  [[ -z $branch ]] && return

  # Read cache
  local cache_file="/tmp/.sparse_git.$$"
  [[ -f $cache_file ]] && source $cache_file

  local staged=${_sparse_git_cache[staged]:-0}
  local unstaged=${_sparse_git_cache[unstaged]:-0}
  local untracked=${_sparse_git_cache[untracked]:-0}
  local cached_dir=${_sparse_git_cache[dir]:-}

  # Show segment if we have cached data for this directory
  if [[ $cached_dir == $PWD ]]; then
    local bg=2  # green (clean)
    (( staged + unstaged > 0 )) && bg=3  # yellow (modified)

    local text=""
    (( $+functions[_p9k_get_icon] )) && { _p9k_get_icon '' VCS_BRANCH_ICON; text+="$_p9k__ret"; }
    text+="$branch"

    if (( staged > 0 )); then
      (( $+functions[_p9k_get_icon] )) && _p9k_get_icon '' VCS_STAGED_ICON
      text+=" ${_p9k__ret:-+}"
    fi
    if (( unstaged > 0 )); then
      (( $+functions[_p9k_get_icon] )) && _p9k_get_icon '' VCS_UNSTAGED_ICON
      text+=" ${_p9k__ret:-!}"
    fi
    if (( untracked > 0 )); then
      (( $+functions[_p9k_get_icon] )) && _p9k_get_icon '' VCS_UNTRACKED_ICON
      text+=" ${_p9k__ret:-?}"
    fi

    p10k segment -b $bg -f black -i 'VCS_GIT_GITHUB_ICON' -t "$text"
  fi

  # Update cache in background
  (
    local s=0 u=0 t=0 line
    while IFS= read -r line; do
      [[ $line[1] == [MADRC] ]] && ((s++))
      [[ $line[2] == [MD] ]] && ((u++))
      [[ $line[1] == "?" ]] && ((t++))
    done < <(git status --porcelain 2>/dev/null)

    cat > "$cache_file" <<EOF
_sparse_git_cache[staged]=$s
_sparse_git_cache[unstaged]=$u
_sparse_git_cache[untracked]=$t
_sparse_git_cache[dir]='$PWD'
EOF
  ) &!
}

function instant_prompt_sparse_git() {
  prompt_sparse_git
}

# ============================================================================
# POWERLEVEL10K CONFIGURATION
# ============================================================================

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

# VCS settings - disable gitstatus for world repo (sparse checkout)
POWERLEVEL9K_VCS_GIT_GITHUB_ICON='\uF408 '
POWERLEVEL9K_VCS_GIT_ICON='\uF408 '
POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='*/world/*'
# Sparse git segment styling (colors set dynamically in function)
POWERLEVEL9K_SPARSE_GIT_VISUAL_IDENTIFIER_EXPANSION=$'\uF408 '

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
  vcs          # gitstatus for normal repos
  sparse_git   # custom for world repo
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
