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

  PATH="$BREW_PACKAGE_PREFIX/*/bin:$PATH"
  PATH="$BREW_PREFIX/lib/ruby/gems/*/bin:$PATH"
fi

PATH="$HOME/.bin:$PATH"
PATH="$HOME/.local/bin:$PATH"
PATH="$HOME/go/bin:$PATH"
PATH="$HOME/.cargo/bin:$PATH"
PATH="$HOME/.local/share/nvim/mason/bin:$PATH"

if ! [ -z "$USER_PATH" ]; then
  PATH="$USER_PATH:$PATH"
fi
export PATH=$PATH
