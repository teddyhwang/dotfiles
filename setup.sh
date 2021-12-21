#!/bin/zsh

./omz.sh
./directories.sh
./linker.sh
./download.sh
./plugins.sh
if [ $SPIN ]; then
  ./spin.sh
fi

if ! [ -d ~/.cache/bat ]; then
  bat cache --build
fi
base16-manager set seti
git config --global include.path ~/.shared.gitconfig

echo -e "$C_GREEN\nInstallation Complete$C_DEFAULT"
