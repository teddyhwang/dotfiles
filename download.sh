#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

if [[ $OSTYPE == 'darwin'* ]]; then
  source './brew.sh'
else
  touch ~/.z
  sudo apt-get install -y bat ranger xdg-utils highlight universal-ctags pip fd-find
  if ! [ -f /usr/bin/bat ]; then
    sudo ln -s /usr/bin/batcat /usr/bin/bat
  fi
  if ! [ -f ~/.bin/fd ]; then
    sudo ln -s $(which fdfind) ~/.bin/fd
  fi

  pip install neovim mycli

  delta_version="0.15.1"
  wget "https://github.com/dandavison/delta/releases/download/${delta_version}/git-delta_${delta_version}_amd64.deb"
  sudo dpkg -i git-delta_${delta}_amd64.deb
  rm *.deb

  if ! [ -d ~/.fzf ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all
  fi
fi

if ! [ -d ~/.tmux ]; then
  echo -e "${C_GREEN}Installing tmux plugin manager...$C_DEFAULT"
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
  echo -e "${C_LIGHTGRAY}tmux plugin manager is installed$C_DEFAULT"
fi

if ! [ -d /usr/local/bin ]; then
  echo -e "${C_GREEN}Adding directory /usr/local/bin...$C_DEFAULT"
  sudo mkdir /usr/local/bin
else
  echo -e "${C_LIGHTGRAY}/usr/local/bin/ exists$C_DEFAULT"
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
