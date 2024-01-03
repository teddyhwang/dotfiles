#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

touch ~/.z
if ! command -v brew &> /dev/null; then
  BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"
  echo -e "${C_GREEN}Installing Brew packages...$C_DEFAULT"
  $BREW_BIN install tmux git-delta fzf bat fd ranger universal-ctags gzip
  $($BREW_BIN --prefix)/opt/fzf/install --all
else
  echo -e "${C_LIGHTGRAY}Brew bundled$C_DEFAULT"
fi
sudo apt-get install -y xdg-utils highlight fd-find
pip install neovim mycli
gem install gem-ripper-tags
