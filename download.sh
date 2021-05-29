#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

if [ $SPIN ]; then
  touch ~/.z
  sudo apt install -o Dpkg::Options::="--force-overwrite" -y bat ripgrep ranger xdg-utils tree highlight
  wget "https://github.com/sharkdp/vivid/releases/download/v0.6.0/vivid_0.6.0_amd64.deb"
  sudo dpkg -i vivid_0.6.0_amd64.deb
  wget "https://github.com/barnumbirr/delta-debian/releases/download/0.6.0-1/delta-diff_0.6.0-1_amd64_debian_buster.deb"
  sudo dpkg -i delta-diff_0.6.0-1_amd64_debian_buster.deb
  rm vivid_0.6.0_amd64.deb delta-diff_0.6.0-1_amd64_debian_buster.deb
  sudo ln -s /usr/bin/batcat /usr/bin/bat

  if [ -d /src/github.com/shopify/shopify ]; then
    mkdir /src/github.com/shopify/shopify/.vim
    cp coc-settings-sorbet.json /src/github.com/shopify/shopify/.vim/coc-settings.json
  elif [ -d /src/github.com/shopify/shopify-dev ]; then
    mkdir /src/github.com/shopify/shopify-dev/.vim
    cp coc-settings-solargraph.json /src/github.com/shopify/shopify-dev/.vim/coc-settings.json
    cd /src/github.com/shopify/shopify-dev/
    bundle config set --local with 'solargraph' && bundle && bundle exec solargraph bundle
    cd -
  else
    gem install solargraph && solargraph bundle
  fi
  gem install gem-ripper-tags && gem ripper_tags || true
  sudo npm install -g prettier || true
else
  if ! [ -x "$(command -v brew)" ]; then
    echo -e "${C_GREEN}Installing Homebrew...$C_DEFAULT"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo -e "${C_GREEN}Installing Brew packages...$C_DEFAULT"
    brew tap "homebrew/bundle"
    brew bundle
    $(brew --prefix)/opt/fzf/install
  else
    echo -e "${C_LIGHTGRAY}Brew is installed$C_DEFAULT"
  fi

  if ! [ -f ~/.bin/tmuxinator.zsh ]; then
    echo -e "${C_GREEN}Adding Tmuxinator script...$C_DEFAULT"
    wget -O ~/.bin/tmuxinator.zsh https://raw.githubusercontent.com/tmuxinator/tmuxinator/master/completion/tmuxinator.zsh
  else
    echo -e "${C_LIGHTGRAY}tmuxinator is installed$C_DEFAULT"
  fi
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

if ! command -v fzf &> /dev/null; then
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all
fi

if ! [ -d ~/.tmux ]; then
  echo -e "${C_GREEN}Installing tmux plugin manager...$C_DEFAULT"
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
  echo -e "${C_LIGHTGRAY}tmux plugin manager is installed$C_DEFAULT"
fi

if ! command -v base16-manager &> /dev/null; then
  echo -e "${C_GREEN}Installing base16-manager...$C_DEFAULT"
  git clone https://github.com/base16-manager/base16-manager && cd base16-manager
  if [ $SPIN ]; then
    sudo make install
  else
    make install
  fi
  cd .. && rm -rf base16-manager
  base16-manager install chriskempson/base16-shell
  base16-manager install chriskempson/base16-vim
  base16-manager install nicodebo/base16-fzf
else
  echo -e "${C_LIGHTGRAY}base16-manager is installed$C_DEFAULT"
fi

if ! [ -f /usr/local/bin/cht.sh ]; then
  echo -e "${C_GREEN}Adding cht.sh...$C_DEFAULT"
  if [ $SPIN ]; then
    sudo wget -O /usr/local/bin/cht.sh https://cht.sh/:cht.sh
    sudo chmod +x /usr/local/bin/cht.sh
  else
    wget -O /usr/local/bin/cht.sh https://cht.sh/:cht.sh
    chmod +x /usr/local/bin/cht.sh
  fi
else
  echo -e "${C_LIGHTGRAY}cht.sh exists$C_DEFAULT"
fi
