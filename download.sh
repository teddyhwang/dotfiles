#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

if [[ $OSTYPE == 'darwin'* ]]; then
  source './brew.sh'
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

if ! command -v prettier &> /dev/null; then
  echo -e "${C_GREEN}Installing prettier...$C_DEFAULT"
  npm install -g prettier || sudo npm install -g prettier
else
  echo -e "${C_LIGHTGRAY}prettier is installed$C_DEFAULT"
fi

if ! command -v bash-language-server &> /dev/null; then
  echo -e "${C_GREEN}Installing bash-language-server...$C_DEFAULT"
  npm install -g bash-language-server || sudo npm install -g bash-language-server
else
  echo -e "${C_LIGHTGRAY}bash-language-server is installed$C_DEFAULT"
fi
