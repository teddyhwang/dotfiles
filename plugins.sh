#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

base16_plugins=(
  'chriskempson/base16-shell'
  'chriskempson/base16-vim'
  'base16-project/base16-fzf'
)

omz_plugins=(
  'zsh-autosuggestions'
  'zsh-completions'
  'zsh-syntax-highlighting'
)

for plugin in $base16_plugins; do
  if [ -d ~/.base16-manager/$plugin ] || [ -d ~/.local/share/base16-manager/$plugin ]; then
    echo -e "${C_LIGHTGRAY}$plugin is installed$C_DEFAULT"
  else
    echo -e "${C_GREEN}Installing $plugin...$C_DEFAULT"
    base16-manager install $plugin
  fi
done

if [ -d ~/.oh-my-zsh/custom/themes/powerlevel10k ]; then
  echo -e "${C_LIGHTGRAY}powerlevel10k is installed$C_DEFAULT"
else
  echo -e "${C_GREEN}Installing powerlevel10k...$C_DEFAULT"
  git clone https://github.com/romkatv/powerlevel10k ~/.oh-my-zsh/custom/themes/powerlevel10k
fi

for plugin in $omz_plugins; do
  if [ -d ~/.oh-my-zsh/custom/plugins/$plugin ]; then
    echo -e "${C_LIGHTGRAY}$plugin is installed$C_DEFAULT"
  else
    echo -e "${C_GREEN}Installing $plugin...$C_DEFAULT"
    git clone https://github.com/zsh-users/$plugin ~/.oh-my-zsh/custom/plugins/$plugin
  fi
done
