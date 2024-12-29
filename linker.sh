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
    echo -e "${C_ORANGE}$target exists and differs from your dotfile.$C_DEFAULT"
    read -r "response?Do you want to replace it? (y/N) "
    echo -e "\033[1A\033[2K\033[1A\033[2K"
    if [[ "$response" =~ ^[Yy]$ ]]; then
      echo -e "${C_RED}Replacing existing file...$C_DEFAULT"
      rm -rf $target && symlink $source $target
    else
      echo -e "${C_LIGHTGRAY}Keeping existing file$C_DEFAULT"
    fi
  else
    echo -e "${C_GREEN}$target does not exist. Symlinking to dotfile.$C_DEFAULT"
    symlink $source $target
  fi
}

function check_broken_symlinks {
  local dotfiles_path=$(realpath $(pwd))
  echo -e "${C_ORANGE}Checking for broken symlinks pointing to dotfiles...$C_DEFAULT"

  find $HOME/\.[^.]* $HOME/.config $HOME/.bin -type l -print0 2>/dev/null | while IFS= read -r -d '' link; do
    target=$(readlink "$link")
    if [[ "$target" == "$dotfiles_path"* ]]; then
      if [[ ! -e "$link" ]]; then
        echo -e "${C_RED}Found broken symlink: $link -> $target$C_DEFAULT"
        echo -e "${C_ORANGE}Removing broken symlink...$C_DEFAULT"
        rm "$link"
      fi
    fi
  done
}

check_broken_symlinks

for filepath in home/.[^.]*; do
  file=$filepath:t
  source="$(pwd)/$filepath"
  target="$HOME/$file"

  validate_and_symlink $file $source $target
done

for filepath in home/config/*; do
  file=$filepath:t
  source="$(pwd)/$filepath"
  target="$HOME/.config/$file"

  validate_and_symlink $file $source $target
done

for filepath in home/bin/*; do
  file=$filepath:t
  source="$(pwd)/$filepath"
  target="$HOME/.bin/$file"

  validate_and_symlink $file $source $target
done
