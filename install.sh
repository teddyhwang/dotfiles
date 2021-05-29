#!/bin/zsh

./add_directories.sh
./download.sh
./linker.sh

bat cache --build
base16-manager set seti

if [ $SPIN ]; then
  stop && start && tmux source ~/.tmux.conf 
  gpgconf --launch dirmngr
  gpg --keyserver keys.openpgp.org --recv 5E3F0946116DFD4C553BEB5CCC211E2E2092D7C3
  nvim --headless +PlugInstall +qall
  timeout 1m nvim --headless +CocInstall || true
  timeout 10s nvim --headless +CocInstall || true
fi

echo -e "$C_GREEN\nInstallation Complete$C_DEFAULT"
