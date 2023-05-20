#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

source './brew.sh'
if [[ $OSTYPE == 'darwin'* ]]; then
  source './mac.sh'
else
  source './linux.sh'
fi

if ! [ -f /usr/local/bin/cht.sh ]; then
  echo -e "${C_GREEN}Adding cht.sh...$C_DEFAULT"
  wget -O /usr/local/bin/cht.sh https://cht.sh/:cht.sh || sudo wget -O /usr/local/bin/cht.sh https://cht.sh/:cht.sh
  chmod +x /usr/local/bin/cht.sh || sudo chmod +x /usr/local/bin/cht.sh
else
  echo -e "${C_LIGHTGRAY}cht.sh exists$C_DEFAULT"
fi

if ! command -v tree-sitter &> /dev/null; then
  echo -e "${C_GREEN}Installing tree-sitter-cli...$C_DEFAULT"
  npm install -g tree-sitter-cli || sudo npm install -g tree-sitter-cli
else
  echo -e "${C_LIGHTGRAY}tree-sitter-cli is installed$C_DEFAULT"
fi
