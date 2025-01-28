if [ -d "/opt/homebrew" ]; then
  BREW_PREFIX="/opt/homebrew"
  BREW_PACKAGE_PREFIX="$BREW_PREFIX/opt"
fi
if [ -f "/usr/local/bin/brew" ]; then
  BREW_PREFIX="/usr/local"
  BREW_PACKAGE_PREFIX="$BREW_PREFIX/opt"
fi
if [ -n "$BREW_PREFIX" ]; then
  DEFAULT_PATH=$(cat /etc/paths | xargs | tr " " :)
  USER_PATH=$(echo $PATH | sed "s/${DEFAULT_PATH//\//\\/}//" | sed "s/^:\(.*\)/\1/")

  PATH="$BREW_PREFIX/bin:$PATH"
  PATH="$BREW_PREFIX/sbin:$PATH"

  PATH="$BREW_PREFIX/opt/ruby/bin:$PATH"

  if [ -d "$BREW_PREFIX/lib/ruby/gems" ]; then
    latest_gems_dir=$(ls -v "$BREW_PREFIX/lib/ruby/gems" | grep '^[0-9]' | tail -n 1)
    if [ -n "$latest_gems_dir" ] && [ -d "$BREW_PREFIX/lib/ruby/gems/$latest_gems_dir/bin" ]; then
      PATH="$BREW_PREFIX/lib/ruby/gems/$latest_gems_dir/bin:$PATH"
    fi
  fi
fi

PATH="$HOME/.bin:$PATH"
PATH="$HOME/.local/bin:$PATH"
PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
PATH="$HOME/go/bin:$PATH"
PATH="$HOME/.cargo/bin:$PATH"

if ! [ -z "$USER_PATH" ]; then
  PATH="$USER_PATH:$PATH"
fi
export PATH=$PATH
