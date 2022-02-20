#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

if [[ $OSTYPE == 'darwin'* ]]; then
  if ! command -v brew &> /dev/null; then
    echo -e "${C_GREEN}Installing Homebrew...$C_DEFAULT"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -f "/usr/local/bin/brew" ]; then
      BREW_BIN="/usr/local/bin/brew"
    else
      BREW_BIN="/opt/homebrew/bin/brew"
    fi
    echo -e "${C_GREEN}Installing Brew packages...$C_DEFAULT"
    $BREW_BIN tap "homebrew/bundle"
    $BREW_BIN bundle
    $($BREW_BIN --prefix)/opt/fzf/install --all

    cp -rf com.amethyst.Amethyst.plist ~/Library/Preferences/com.amethyst.Amethyst.plist
    cp -rf lazygit.config.yml ~/Library/Application Support/lazygit/config.yml

    if [ -f ~/Library/LaunchAgents/pbcopy.plist ]; then
      cp pbcopy.plist ~/Library/LaunchAgents/.
      cp pbpaste.plist ~/Library/LaunchAgents/.
      launchctl load ~/Library/LaunchAgents/pbcopy.plist
      launchctl load ~/Library/LaunchAgents/pbpaste.plist
    fi

    echo "pinentry-mac $(which pinentry-mac)" | tee ~/.gnupg/gpg-agent.conf
  else
    echo -e "${C_LIGHTGRAY}Brew is installed$C_DEFAULT"
  fi
else
  touch ~/.z
  sudo apt-get install -y bat ranger xdg-utils highlight universal-ctags pip
  sudo ln -s /usr/bin/batcat /usr/bin/bat
  sudo npm install -g prettier || true

  pip install neovim

  wget "https://github.com/dandavison/delta/releases/download/0.11.3/git-delta_0.11.3_amd64.deb"
  sudo dpkg -i git-delta_0.11.3_amd64.deb
  rm *.deb

  if ! [ -d ~/.fzf ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all
  fi
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
  make install || sudo make install
  cd .. && rm -rf base16-manager
else
  echo -e "${C_LIGHTGRAY}base16-manager is installed$C_DEFAULT"
fi

if ! [ -f /usr/local/bin/cht.sh ]; then
  echo -e "${C_GREEN}Adding cht.sh...$C_DEFAULT"
  wget -O /usr/local/bin/cht.sh https://cht.sh/:cht.sh || sudo wget -O /usr/local/bin/cht.sh https://cht.sh/:cht.sh
  chmod +x /usr/local/bin/cht.sh || sudo chmod +x /usr/local/bin/cht.sh
else
  echo -e "${C_LIGHTGRAY}cht.sh exists$C_DEFAULT"
fi
