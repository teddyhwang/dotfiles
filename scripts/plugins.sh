#!/bin/zsh

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/print.sh"

omz_plugins=(
  'zsh-users/zsh-autosuggestions'
  'zsh-users/zsh-completions'
  'zsh-users/zsh-syntax-highlighting'
)

print_progress "Installing custom zsh themes and plugins..."

if [ -d ~/.oh-my-zsh/custom/themes/powerlevel10k ]; then
  print_info "powerlevel10k is installed"
else
  print_progress "Installing powerlevel10k..."
  git clone https://github.com/romkatv/powerlevel10k ~/.oh-my-zsh/custom/themes/powerlevel10k
  track_change
fi

for plugin in $omz_plugins; do
  plugin_name=$(echo $plugin | cut -d '/' -f 2)
  if [ -d ~/.oh-my-zsh/custom/plugins/$plugin_name ]; then
    print_info "$plugin_name is installed"
  else
    print_progress "Installing $plugin_name..."
    git clone https://github.com/$plugin ~/.oh-my-zsh/custom/plugins/$plugin_name
    track_change
  fi
done

if [ -d ~/.oh-my-zsh/custom/completions ]; then
  print_info "Custom completions added"
else
  print_progress "Adding custom completions..."
  mkdir -p ~/.oh-my-zsh/custom/completions
  cp ./home/completions/* ~/.oh-my-zsh/custom/completions/.
  track_change
fi

print_conditional_success "Plugins"
