#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

echo -e "${C_GREEN}Starting installation...$C_DEFAULT"

if ! [ -d ~/.oh-my-zsh ]; then
  echo -e "${C_GREEN}Installing Oh My ZSH...${C_DEFAULT}"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo -e "${C_LIGHTGRAY}Oh My ZSH is installed${C_DEFAULT}"
fi
