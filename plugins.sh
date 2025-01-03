#!/bin/zsh

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/print.sh"

omz_plugins=(
  'zsh-users/zsh-autosuggestions'
  'zsh-users/zsh-completions'
  'zsh-users/zsh-syntax-highlighting'
)

if [ -d ~/.oh-my-zsh/custom/themes/powerlevel10k ]; then
  print_info "powerlevel10k is installed"
else
  print_progress "Installing powerlevel10k..."
  git clone https://github.com/romkatv/powerlevel10k ~/.oh-my-zsh/custom/themes/powerlevel10k
fi

for plugin in $omz_plugins; do
  plugin_name=$(echo $plugin | cut -d '/' -f 2)
  if [ -d ~/.oh-my-zsh/custom/plugins/$plugin_name ]; then
    print_info "$plugin_name is installed"
  else
    print_progress "Installing $plugin_name..."
    git clone https://github.com/$plugin ~/.oh-my-zsh/custom/plugins/$plugin_name
  fi
done

print_success "Plugins installed 🎉"
