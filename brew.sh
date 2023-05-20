#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

if ! command -v brew &> /dev/null; then
  echo -e "${C_GREEN}Installing Homebrew...$C_DEFAULT"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo -e "${C_LIGHTGRAY}Brew is installed$C_DEFAULT"
fi
