#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

omz_plugins=(
  'tinted-theming/base16-shell'
  'zsh-users/zsh-autosuggestions'
  'zsh-users/zsh-completions'
  'zsh-users/zsh-syntax-highlighting'
)

if [ -d ~/.config/base16-fzf ]; then
  echo -e "${C_LIGHTGRAY}base16-fzf is installed$C_DEFAULT"
else
  echo -e "${C_GREEN}Installing base16-fzf...$C_DEFAULT"
  git clone https://github.com/tinted-theming/base16-fzf ~/.config/base16-fzf
fi

if [ -d ~/.oh-my-zsh/custom/themes/powerlevel10k ]; then
  echo -e "${C_LIGHTGRAY}powerlevel10k is installed$C_DEFAULT"
else
  echo -e "${C_GREEN}Installing powerlevel10k...$C_DEFAULT"
  git clone https://github.com/romkatv/powerlevel10k ~/.oh-my-zsh/custom/themes/powerlevel10k
fi

for plugin in $omz_plugins; do
  plugin_name=$(echo $plugin | cut -d '/' -f 2)
  if [ -d ~/.oh-my-zsh/custom/plugins/$plugin_name ]; then
    echo -e "${C_LIGHTGRAY}$plugin_name is installed$C_DEFAULT"
  else
    echo -e "${C_GREEN}Installing $plugin_name...$C_DEFAULT"
    git clone https://github.com/$plugin ~/.oh-my-zsh/custom/plugins/$plugin_name
  fi
done
