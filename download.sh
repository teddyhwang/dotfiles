#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

if [[ $OSTYPE == 'darwin'* ]]; then
  if ! command -v brew &> /dev/null; then
    echo -e "${C_GREEN}Installing Homebrew...$C_DEFAULT"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo -e "${C_GREEN}Installing Brew packages...$C_DEFAULT"
    brew tap "homebrew/bundle"
    brew bundle
    $(brew --prefix)/opt/fzf/install --all
    cp -rf com.amethyst.Amethyst.plist ~/Library/Preferences/com.amethyst.Amethyst.plist
    if [ -f /opt/homebrew/bin/pinentry-mac ]; then
      echo 'pinentry-program /opt/homebrew/bin/pinentry-mac' | tee ~/.gnupg/gpg-agent.conf
    else
      echo 'pinentry-program /usr/local/bin/pinentry-mac' | tee ~/.gnupg/gpg-agent.conf
    fi
  else
    echo -e "${C_LIGHTGRAY}Brew is installed$C_DEFAULT"
  fi
else
  touch ~/.z
  sudo apt-get install -y bat ranger xdg-utils highlight universal-ctags
  sudo ln -s /usr/bin/batcat /usr/bin/bat

  wget "https://github.com/barnumbirr/delta-debian/releases/download/0.6.0-1/delta-diff_0.6.0-1_amd64_debian_buster.deb"
  sudo dpkg -i delta-diff_0.6.0-1_amd64_debian_buster.deb
  rm *.deb

  if ! command -v fzf &> /dev/null; then
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
