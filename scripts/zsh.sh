#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

print_progress "Installing OhMyZSH..."

if ! [ -d ~/.oh-my-zsh ]; then
  print_progress "Installing OhMyZsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  print_info "Oh My ZSH is installed"
fi

print_conditional_success "OhMyZsh"

omz_plugins="zsh-users/zsh-autosuggestions zsh-users/zsh-completions zsh-users/zsh-syntax-highlighting mafredri/zsh-async"

print_progress "Installing custom zsh themes and plugins..."

if [ -d ~/.oh-my-zsh/custom/themes/powerlevel10k ]; then
  print_info "powerlevel10k is installed"
else
  print_progress "Installing powerlevel10k..."
  git clone https://github.com/romkatv/powerlevel10k ~/.oh-my-zsh/custom/themes/powerlevel10k
  track_change
fi

for plugin in $omz_plugins; do
  plugin_name=$(echo "$plugin" | cut -d '/' -f 2)
  if [ -d ~/.oh-my-zsh/custom/plugins/"$plugin_name" ]; then
    print_info "$plugin_name is installed"
  else
    print_progress "Installing $plugin_name..."
    git clone "https://github.com/$plugin" ~/.oh-my-zsh/custom/plugins/"$plugin_name"
    track_change
  fi
done

# zsh-async needs a symlink for oh-my-zsh to recognize it
if [ -d ~/.oh-my-zsh/custom/plugins/zsh-async ] && [ ! -L ~/.oh-my-zsh/custom/plugins/zsh-async/zsh-async.plugin.zsh ]; then
  print_progress "Creating zsh-async symlink..."
  ln -sf async.plugin.zsh ~/.oh-my-zsh/custom/plugins/zsh-async/zsh-async.plugin.zsh
  track_change
fi

if [ -d ~/.oh-my-zsh/custom/completions ]; then
  print_info "Custom completions added"
else
  print_progress "Adding custom completions..."
  mkdir -p ~/.oh-my-zsh/custom/completions
  cp ./home/completions/* ~/.oh-my-zsh/custom/completions/.
  track_change
fi

print_conditional_success "Plugins"
