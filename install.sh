#!/bin/bash
if [ $SPIN ]; then
  if ! command -v rg &> /dev/null; then
    sudo apt-get install -y ripgrep
  fi

  if ! command -v fzf &> /dev/null; then
    sudo apt-get install -y fzf
  fi

  if ! command -v ranger &> /dev/null; then
    sudo apt-get install -y ranger
  fi

  if ! command -v base16-manager &> /dev/null; then
    git clone https://github.com/base16-manager/base16-manager && cd base16-manager && sudo make install && cd .. && rm -rf base16-manager
  fi
fi

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

echo -e "$C_GREEN\nStarting Installation...$C_DEFAULT"

if ! [ -d ~/.oh-my-zsh ]; then
  echo -e "${C_GREEN}Installing Oh My ZSH...$C_DEFAULT"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
else
  echo -e "${C_LIGHTGRAY}Oh My ZSH is installed$C_DEFAULT"
fi
if ! [ -d ~/.oh-my-zsh/custom/themes/powerlevel10k ]; then
  echo -e "${C_GREEN}Installing Oh My ZSH Themes...$C_DEFAULT"
  git clone git@github.com:romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
else
  echo -e "${C_LIGHTGRAY}Powerlevel10k is installed$C_DEFAULT"
fi
if ! [ -d ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions ]; then
  echo -e "${C_GREEN}Installing Oh My ZSH Plugins...$C_DEFAULT"
  git clone git@github.com:zsh-users/zsh-autosuggestions.git ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
else
  echo -e "${C_LIGHTGRAY}ZSH Autosuggestions is installed$C_DEFAULT"
fi
if ! [ -d ~/.oh-my-zsh/custom/plugins/zsh-completions ]; then
  echo -e "${C_GREEN}Installing Oh My ZSH Plugins...$C_DEFAULT"
  git clone git@github.com:zsh-users/zsh-completions.git ~/.oh-my-zsh/custom/plugins/zsh-completions
else
  echo -e "${C_LIGHTGRAY}ZSH Complettions is installed$C_DEFAULT"
fi
if ! [ -d ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting ]; then
  echo -e "${C_GREEN}Installing Oh My ZSH Plugins...$C_DEFAULT"
  git clone git@github.com:zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
else
  echo -e "${C_LIGHTGRAY}ZSH Syntax Highlighting is installed$C_DEFAULT"
fi

if ! [ -d ~/.tmux ]; then
  echo -e "${C_GREEN}Installing tmux plugin manager...$C_DEFAULT"
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
  echo -e "${C_LIGHTGRAY}tmux plugin manager is installed$C_DEFAULT"
fi

if ! [ -f ~/.base16_theme ]; then
  echo -e "${C_GREEN}Installing base16...$C_DEFAULT"
  base16-manager install chriskempson/base16-shell
  base16-manager install chriskempson/base16-vim
  base16-manager install nicodebo/base16-fzf
  echo -e "${C_GREEN}Symlinking base16 script...$C_DEFAULT"
  ln -s .base16-manager/chriskempson/base16-shell/scripts/base16-seti.sh ~/.base16_theme
else
  echo -e "${C_LIGHTGRAY}base16 script is installed$C_DEFAULT"
fi
if ! [ -d ~/.vim ]; then
  echo -e "${C_GREEN}Creating .vim folder...$C_DEFAULT"
  mkdir ~/.vim
else
  echo -e "${C_LIGHTGRAY}.vim exists$C_DEFAULT"
fi
if ! [ -d ~/.vim_swap ]; then
  echo -e "${C_GREEN}Creating .vim_swap folder...$C_DEFAULT"
  mkdir ~/.vim_swap
else
  echo -e "${C_LIGHTGRAY}.vim_swap exists$C_DEFAULT"
fi
if ! [ -d ~/.config ]; then
  echo -e "${C_GREEN}Creating .config folder...$C_DEFAULT"
  mkdir ~/.config
else
  echo -e "${C_LIGHTGRAY}.config exists$C_DEFAULT"
fi

./linker.sh
bat cache --build

echo -e "$C_GREEN\nINSTALLATION COMPLETE$C_DEFAULT"
