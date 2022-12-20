#!/bin/zsh

./omz.sh
./directories.sh
./linker.sh
./download.sh
./plugins.sh
./tmux.sh
if [ $SPIN ]; then
  ./spin.sh
fi
./complete.sh
