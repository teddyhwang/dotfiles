#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

if ! [ -d ~/.tmux ]; then
  echo -e "${C_GREEN}Installing tmux plugin manager...$C_DEFAULT"
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
  echo -e "${C_LIGHTGRAY}tmux plugin manager is installed$C_DEFAULT"
fi

if [ ! -d ~/.tmux/plugins/base16-tmux-powerline ]; then
  echo -e "${C_GREEN}Installing tmux plugins...$C_DEFAULT"
  tmux new-session -d "sleep 1"
  sleep 0.1
  ~/.tmux/plugins/tpm/bin/install_plugins
else
  echo -e "${C_LIGHTGRAY}tmux plugins installed$C_DEFAULT"
fi
