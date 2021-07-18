#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_RED="\x1B[31m"
C_LIGHTGRAY="\x1B[90m"
C_ORANGE="\x1B[33m"

function symlink {
  ln -nsf $1 $2
}

function validate_and_symlink {
  file=$1
  source=$2
  target=$3

  if [ $file = ".DS_Store" ]; then
    echo -e "${C_LIGHTGRAY}Ignoring system file.$C_DEFAULT"
  elif [[ -h $target && ($(readlink $target) == $source)]]; then
    echo -e "${C_LIGHTGRAY}$target is symlinked to your dotfiles.$C_DEFAULT"
  elif [[ -a $target ]]; then
    if [[ $OSTYPE != 'darwin'* ]]; then
      echo -e "${C_RED}$target exists and differs from your dotfile; replacing file$C_DEFAULT"
      rm -rf $target && symlink $source $target
    else
      echo -e "${C_ORANGE}$target exists and differs from your dotfile.$C_DEFAULT"
    fi
  else
    echo -e "${C_GREEN}$target does not exist. Symlinking to dotfile.$C_DEFAULT"
    symlink $source $target
  fi
}

for filepath in home/.[^.]*; do
  file=$filepath:t
  source="$(pwd)/$filepath"
  target="$HOME/$file"

  validate_and_symlink $file $source $target
done

for filepath in home/vim/*; do
  file=$filepath:t
  source="$(pwd)/$filepath"
  target="$HOME/.vim/$file"

  validate_and_symlink $file $source $target
done

for filepath in home/config/*; do
  file=$filepath:t
  source="$(pwd)/$filepath"
  target="$HOME/.config/$file"

  validate_and_symlink $file $source $target
done

if [[ $OSTYPE != 'darwin'* ]]; then
  for filepath in home/bin/*; do
    file=$filepath:t
    source="$(pwd)/$filepath"
    target="$HOME/.bin/$file"

    validate_and_symlink $file $source $target
  done
fi
