#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

if ! [ -d ~/.cache/bat ]; then
  bat cache --build
fi

if git config --get-all include.path | grep -q .shared.gitconfig; then
  echo -e "${C_LIGHTGRAY}include.path already set with ~/.shared.gitconfig$C_DEFAULT"
else
  echo -e "${C_GREEN}Adding shared git config include,path...$C_DEFAULT"
  git config --global include.path ~/.shared.gitconfig
fi

echo -e "${C_GREEN}Installation complete 🎉$C_DEFAULT"
