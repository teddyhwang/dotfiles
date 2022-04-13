#!zsh

./omz.sh
./directories.sh
./linker.sh
./download.sh
./plugins.sh
./tmux.sh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

if [ $SPIN ]; then
  ./spin.sh
fi

if ! [ -d ~/.cache/bat ]; then
  bat cache --build
fi

if git config --get-all include.path | grep -q .shared.gitconfig; then
  echo -e "${C_LIGHTGRAY}\ninclude.path already set with ~/.shared.gitconfig$C_DEFAULT"
else
  git config --global include.path ~/.shared.gitconfig
fi

base16-manager set seti

echo -e "$C_GREEN\nInstallation Complete$C_DEFAULT"
