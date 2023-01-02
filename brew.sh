#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

if ! command -v brew &> /dev/null; then
  echo -e "${C_GREEN}Installing Homebrew...$C_DEFAULT"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -f "/usr/local/bin/brew" ]; then
    BREW_BIN="/usr/local/bin/brew"
  else
    BREW_BIN="/opt/homebrew/bin/brew"
  fi
  echo -e "${C_GREEN}Installing Brew packages...$C_DEFAULT"
  $BREW_BIN tap "homebrew/bundle"
  $BREW_BIN bundle
  $($BREW_BIN --prefix)/opt/fzf/install --all
else
  echo -e "${C_LIGHTGRAY}Brew is installed$C_DEFAULT"
fi
