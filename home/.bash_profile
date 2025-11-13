[[ -f "$HOME/.local/share/../bin/env" ]] && . "$HOME/.local/share/../bin/env"
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

if [[ -d "/opt/homebrew" ]]; then
  BREW_PREFIX="/opt/homebrew"
fi
if [[ -f "/usr/local/bin/brew" ]]; then
  BREW_PREFIX="/usr/local"
fi
if [[ -n "$BREW_PREFIX" ]]; then
  DEFAULT_PATH=$(cat /etc/paths | xargs | tr " " :)
  USER_PATH=$(echo "$PATH" | sed "s/${DEFAULT_PATH//\//\\/}//" | sed "s/^:\(.*\)/\1/")

  PATH="$BREW_PREFIX/bin:$PATH"
  PATH="$BREW_PREFIX/sbin:$PATH"

  PATH="$BREW_PREFIX/opt/ruby/bin:$PATH"

  if [[ -d "$BREW_PREFIX/lib/ruby/gems" ]]; then
    latest_gems_dir=$(find "$BREW_PREFIX/lib/ruby/gems" -maxdepth 1 -type d -name '[0-9]*' | sort -V | tail -n 1 | xargs basename)
    if [[ -n "$latest_gems_dir" && -d "$BREW_PREFIX/lib/ruby/gems/$latest_gems_dir/bin" ]]; then
      PATH="$BREW_PREFIX/lib/ruby/gems/$latest_gems_dir/bin:$PATH"
    fi
  fi
fi

[[ -d "$HOME/.bin" ]] && PATH="$HOME/.bin:$PATH"
[[ -d "$HOME/.local/bin" ]] && PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/.local/share/nvim/mason/bin" ]] && PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
[[ -d "$HOME/go/bin" ]] && PATH="$HOME/go/bin:$PATH"
[[ -d "$HOME/.cargo/bin" ]] && PATH="$HOME/.cargo/bin:$PATH"

if [[ -n "$USER_PATH" ]]; then
  PATH="$USER_PATH:$PATH"
fi
export PATH=$PATH

[[ -f ~/.bashrc ]] && . ~/.bashrc
