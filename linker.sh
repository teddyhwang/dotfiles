#!/bin/bash

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"
C_ORANGE="\x1B[33m"

function symlink {
  ln -nsf $1 $2
}

for file in home/.[^.]*; do
  path="$(pwd)/$file"
  base=$(basename $file)
  target="$HOME/$(basename $file)"

  if [ $file == 'home/.DS_Store' ]; then
    echo -e "${C_LIGHTGRAY}Ignoring system file.$C_DEFAULT"
  elif [[ -h $target && ($(readlink $target) == $path)]]; then
    echo -e "${C_LIGHTGRAY}~/$base is symlinked to your dotfiles.$C_DEFAULT"
  elif [[ -a $target ]]; then
    echo -e "${C_ORANGE}~/$base exists and differs from your dotfile.$C_DEFAULT"
  else
    echo -e "${C_GREEN}~/$base does not exist. Symlinking to dotfile.$C_DEFAULT"
    symlink $path $target
  fi
done

for file in home/vim/*; do
  path="$(pwd)/$file"
  base=$(basename $file)
  target="$HOME/.vim/$(basename $file)"

  if [ $file == 'home/vim/.DS_Store' ]; then
    echo -e "${C_LIGHTGRAY}Ignoring system file.$C_DEFAULT"
  elif [[ -h $target && ($(readlink $target) == $path)]]; then
    echo -e "${C_LIGHTGRAY}~/.vim/$base is symlinked to your dotfiles.$C_DEFAULT"
  elif [[ -a $target ]]; then
    echo -e "${C_ORANGE}~/.vim/$base exists and differs from your dotfile.$C_DEFAULT"
  else
    echo -e "${C_GREEN}~/.vim/$base does not exist. Symlinking to dotfile.$C_DEFAULT"
    symlink $path $target
  fi
done

for file in home/config/*; do
  path="$(pwd)/$file"
  base=$(basename $file)
  target="$HOME/.config/$(basename $file)"

  if [ $file == 'home/config/.DS_Store' ]; then
    echo -e "${C_LIGHTGRAY}Ignoring system file.$C_DEFAULT"
  elif [[ -h $target && ($(readlink $target) == $path)]]; then
    echo -e "${C_LIGHTGRAY}~/.config/$base is symlinked to your dotfiles.$C_DEFAULT"
  elif [[ -a $target ]]; then
    echo -e "${C_ORANGE}~/.config/$base exists and differs from your dotfile.$C_DEFAULT"
  else
    echo -e "${C_GREEN}~/.config/$base does not exist. Symlinking to dotfile.$C_DEFAULT"
    symlink $path $target
  fi
done
