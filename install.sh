#!/bin/bash

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

function add_directory_in_home {
  if ! [ -d ~/$1 ]; then
    echo -e "${C_GREEN}Creating $1 folder...$C_DEFAULT"
    mkdir ~/$1
  else
    echo -e "${C_LIGHTGRAY}$1 exists$C_DEFAULT"
  fi
}

echo -e "${C_GREEN}\nStarting Installation...$C_DEFAULT"

add_directory_in_home '.config'
add_directory_in_home '.ssh'
add_directory_in_home '.vim'
add_directory_in_home '.vim_swap'

if ! command -v fzf &> /dev/null; then
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all
fi

if ! command -v base16-manager &> /dev/null; then
  echo -e "${C_GREEN}Installing base16-manager...$C_DEFAULT"
  git clone https://github.com/base16-manager/base16-manager && cd base16-manager && sudo make install && cd .. && rm -rf base16-manager
  wget "https://github.com/sharkdp/vivid/releases/download/v0.6.0/vivid_0.6.0_amd64.deb"
  base16-manager install chriskempson/base16-shell
  base16-manager install chriskempson/base16-vim
  base16-manager install nicodebo/base16-fzf
else
  echo -e "${C_LIGHTGRAY}base16-manager is installed$C_DEFAULT"
fi

if ! [ -d ~/.oh-my-zsh ]; then
  echo -e "${C_GREEN}Installing Oh My ZSH..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
  echo -e "${C_GREEN}Installing Oh My ZSH Themes...$C_DEFAULT"
  git clone https://github.com/romkatv/powerlevel10k ~/.oh-my-zsh/custom/themes/powerlevel10k
  echo -e "${C_GREEN}Installing Oh My ZSH Plugins...$C_DEFAULT"
  git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
else
  echo -e "${C_LIGHTGRAY}Oh My ZSH is installed"
fi

if ! [ -d ~/.tmux ]; then
  echo -e "${C_GREEN}Installing tmux plugin manager...$C_DEFAULT"
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
  echo -e "${C_LIGHTGRAY}tmux plugin manager is installed$C_DEFAULT"
fi

if [ $SPIN ]; then
  rm -rf ~/.config/nvim
  rm -rf ~/.zshrc
  rm -rf ~/.gitconfig
  touch ~/.z
  ssh-keyscan -H github.com >> ~/.ssh/known_hosts
  sudo apt install -o Dpkg::Options::="--force-overwrite" -y bat ripgrep ranger xdg-utils tree
  sudo dpkg -i vivid_0.6.0_amd64.deb
  wget "https://github.com/barnumbirr/delta-debian/releases/download/0.6.0-1/delta-diff_0.6.0-1_amd64_debian_buster.deb"
  sudo dpkg -i delta-diff_0.6.0-1_amd64_debian_buster.deb
  rm vivid_0.6.0_amd64.deb delta-diff_0.6.0-1_amd64_debian_buster.deb
  gem install solargraph
  gem install gem-ripper-tags
fi

./linker.sh

batcat cache --build
base16-manager set seti
nvim --headless +PlugInstall +qall

if [ $SPIN ]; then
  tmux source ~/.tmux.conf && stop && start
fi

echo -e "$C_GREEN\nInstallation Complete$C_DEFAULT"
