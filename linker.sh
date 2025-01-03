#!/bin/zsh

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/print.sh"

function symlink {
  ln -nsf $1 $2
}

function validate_and_symlink {
  file=$1
  source=$2
  target=$3

  if [ $file = ".DS_Store" ]; then
    print_info "Ignoring system file."
  elif [[ -h $target && ($(readlink $target) == $source)]]; then
    print_info "$target is symlinked to your dotfiles."
  elif [[ -a $target ]]; then
    print_warning "$target exists and differs from your dotfile."
    read -r "response?Do you want to replace it? (y/N) "
    echo -e "\033[1A\033[2K\033[1A"
    if [[ "$response" =~ ^[Yy]$ ]]; then
      print_progress "Replacing existing file..."
      rm -rf $target && symlink $source $target
      track_change
    else
      print_warning "Keeping existing file"
    fi
  else
    print_progress "$target does not exist. Symlinking to dotfile."
    symlink $source $target
    track_change
  fi
}

function check_broken_symlinks {
  local dotfiles_path=$(realpath $(pwd))
  print_progress "Checking for broken symlinks pointing to dotfiles..."

  find $HOME/\.[^.]* $HOME/.config $HOME/.bin -type l -print0 2>/dev/null | while IFS= read -r -d '' link; do
    target=$(readlink "$link")
    if [[ "$target" == "$dotfiles_path"* ]]; then
      if [[ ! -e "$link" ]]; then
        print_error "Found broken symlink: $link -> $target"
        print_progress "Removing broken symlink..."
        rm "$link"
        track_change
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

print_conditional_success "Symlinks"
