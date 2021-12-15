DEFAULT_PATH=$(cat /etc/paths | xargs | tr " " :)
USER_PATH=$(echo $PATH | sed "s/${DEFAULT_PATH//\//\\/}//" | sed "s/^:\(.*\)/\1/")

if [ -d "/opt/homebrew" ]; then
  BREW_PREFIX="/opt/homebrew"
  BREW_PACKAGE_PREFIX="$BREW_PREFIX/opt"
else
  BREW_PREFIX="/usr/local"
  BREW_PACKAGE_PREFIX="$BREW_PREFIX/opt"
fi

PATH=$DEFAULT_PATH
if [ -d "/opt/homebrew/bin" ]; then
  PATH="/opt/homebrew/bin:$PATH"
fi
if [ -d "/opt/homebrew/sbin" ]; then
  PATH="/opt/homebrew/sbin:$PATH"
fi
PATH="$BREW_PACKAGE_PREFIX/curl/bin:$PATH"
PATH="$BREW_PACKAGE_PREFIX/openssl/bin:$PATH"
PATH="$BREW_PACKAGE_PREFIX/ruby/bin:$PATH"
PATH="$BREW_PREFIX/lib/ruby/gems/3.0.0/bin:$PATH"
PATH=$(npm bin):$PATH
PATH=$HOME/go/bin:$PATH
if ! [ -z $USER_PATH ]; then 
  PATH=$USER_PATH:$PATH
fi

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_COLLATE=en_US.UTF-8
export PATH=$PATH
