#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

touch ~/.z
sudo apt-get install -y bat ranger xdg-utils highlight universal-ctags pip fd-find

if ! [ -f /usr/bin/bat ]; then
  sudo ln -s /usr/bin/batcat /usr/bin/bat
fi
if ! [ -f /usr/bin/fd ]; then
  sudo ln -s $(which fdfind) /usr/bin/fd
fi

pip install neovim mycli

delta_version="0.15.1"
wget "https://github.com/dandavison/delta/releases/download/${delta_version}/git-delta_${delta_version}_amd64.deb"
sudo dpkg -i git-delta_${delta}_amd64.deb
rm *.deb

if ! [ -d ~/.fzf ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all
fi
