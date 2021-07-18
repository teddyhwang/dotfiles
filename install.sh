#!/bin/zsh

./add_directories.sh
./download.sh
./linker.sh
if [ $SPIN ]; then
  ./spin.sh
fi

bat cache --build
base16-manager set seti

echo -e "$C_GREEN\nInstallation Complete$C_DEFAULT"
