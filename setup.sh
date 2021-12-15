#!/bin/zsh

./add_directories.sh
./linker.sh
./download.sh
./init.sh
if [ $SPIN ]; then
  ./spin.sh
fi

if ! [ -d ~/.cache/bat ]; then
  bat cache --build
fi
base16-manager set seti

echo -e "$C_GREEN\nInstallation Complete$C_DEFAULT"
