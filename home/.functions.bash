tinty_source_shell_theme() {
  local tinty_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tinted-theming/tinty"

  if [ "$1" = "init" ]; then
    tinty "$@"
    while IFS= read -r script; do
      . "$script"
    done < <(find "$tinty_data_dir" -maxdepth 1 -name "*.sh")
  elif [ "$1" = "apply" ]; then
    local newer_file
    newer_file=$(mktemp)
    tinty "$@"
    while IFS= read -r script; do
      . "$script"
    done < <(find "$tinty_data_dir" -maxdepth 1 -name "*.sh" -newer "$newer_file")
    rm -f "$newer_file"
  else
    tinty "$@"
  fi
}

theme() {
  tinty_source_shell_theme apply "$(tinty list | fzf)"
}

if command -v tinty &> /dev/null; then
  if [[ $- == *i* ]] && [[ -z "$FLOATERM" ]] && [[ -z "$NVIM" ]]; then
    eval "$(tinty generate-completion bash)"
    alias tinty=tinty_source_shell_theme
    tinty_source_shell_theme "init" > /dev/null
  fi
fi

ssh() {
  case "$1" in
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
      command ssh "$(spin show --output fqdn)"
      ;;
    *)
      command ssh "$@"
      ;;
  esac
}

tmux() {
  case "$1" in
    start)
      if [ -n "$TMUX" ]; then
        command tmux new-session -d -s "$2"
        command tmux rename-window -t "$2:0" Terminal
        command tmux new-window -t "$2" -n Editor
        command tmux new-window -t "$2" -n Server
        command tmux select-window -t "$2:0"
        command tmux switch-client -t "$2"
      else
        command tmux new-session -s "$2"
        command tmux rename-window -t "$2:0" Terminal
        command tmux new-window -t "$2" -n Editor
        command tmux new-window -t "$2" -n Server
        command tmux select-window -t "$2:0"
      fi
      ;;
    *)
      command tmux "$@"
      ;;
  esac
}

killport() {
  lsof -i "tcp:$1" | awk 'NR!=1 {print $2}' | xargs kill -9
}

branch() {
  if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git for-each-ref --color --sort=-committerdate \
      refs/heads/ \
      --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) | (%(color:green)%(committerdate:relative)%(color:reset)) %(color:bold)%(authorname)%(color:reset) - %(contents:subject)' | \
      fzf --ansi | \
      cut -f1 -d'|' | \
      xargs)

    if [ -n "$branch" ] ; then
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

    if [ -n "$branch" ] ; then
      git checkout "$branch"
    fi
  else
    echo 'ERROR: Not a git repository'
  fi
}

upstream() {
  branch=$(git rev-parse --abbrev-ref HEAD)
  if [ -n "$branch" ] ; then
    git branch --set-upstream-to="origin/$branch" "$branch"
  fi
}

lg() {
  export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir

  lazygit "$@"

  if [ -f "$LAZYGIT_NEW_DIR_FILE" ]; then
    cd "$(cat "$LAZYGIT_NEW_DIR_FILE")" || return
    rm -f "$LAZYGIT_NEW_DIR_FILE" > /dev/null
  fi
}

tig() {
  command tig "$@" --pretty=fuller
}

y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd" || return
  fi
  rm -f -- "$tmp"
}
