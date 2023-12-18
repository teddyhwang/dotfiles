#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

if ! command -v brew &> /dev/null; then
  if [ -f "/usr/local/bin/brew" ]; then
    BREW_BIN="/usr/local/bin/brew"
  else
    BREW_BIN="/opt/homebrew/bin/brew"
  fi
  echo -e "${C_GREEN}Installing Brew packages...$C_DEFAULT"
  $BREW_BIN tap "homebrew/bundle"
  $BREW_BIN bundle
  $($BREW_BIN --prefix)/opt/fzf/install --all
else
  echo -e "${C_LIGHTGRAY}Brew bundled$C_DEFAULT"
fi

if ! [ -f ~/Library/Preferences/com.amethyst.Amethyst.plist ]; then
  echo -e "${C_GREEN}Copying Amethyst config file...$C_DEFAULT"
  cp -rf ./app_configs/amethyst/com.amethyst.Amethyst.plist ~/Library/Preferences/com.amethyst.Amethyst.plist
else
  echo -e "${C_LIGHTGRAY}Amethyst config file is copied$C_DEFAULT"
fi

if ! [ -f ~/Library/Application\ Support/Amethyst/Layouts/uniform-columns.js ]; then
  echo -e "${C_GREEN}Copying Amethyst custom layout file...$C_DEFAULT"
  cp -rf ./app_configs/amethyst/uniform-columns.js ~/Library/Application\ Support/Amethyst/Layouts/uniform-columns.js
else
  echo -e "${C_LIGHTGRAY}Amethyst custom layout file is copied$C_DEFAULT"
fi

if ! [ -f ~/Library/Application\ Support/lazygit/config.yml ]; then
  echo -e "${C_GREEN}Copying lazygit config file...$C_DEFAULT"
  sudo cp -rf ./app_configs/lazygit.config.yml ~/Library/Application\ Support/lazygit/config.yml
else
  echo -e "${C_LIGHTGRAY}lazygit config file is copied$C_DEFAULT"
fi

if ! [ -f ~/Library/LaunchAgents/pbcopy.plist ]; then
  echo -e "${C_GREEN}Copying launch agent config files...$C_DEFAULT"
  cp app_configs/pbcopy.plist ~/Library/LaunchAgents/.
  cp app_configs/pbpaste.plist ~/Library/LaunchAgents/.
  launchctl load ~/Library/LaunchAgents/pbcopy.plist
  launchctl load ~/Library/LaunchAgents/pbpaste.plist
else
  echo -e "${C_LIGHTGRAY}launch agent config files are copied$C_DEFAULT"
fi

if cat ~/.gnupg/gpg-agent.conf | grep -q pinentry-mac; then
  echo -e "${C_LIGHTGRAY}pinentry-mac is already set$C_DEFAULT"
else
  echo -e "${C_GREEN}Setting pinentry-mac...$C_DEFAULT"
  echo "pinentry-mac $(which pinentry-mac)" | tee ~/.gnupg/gpg-agent.conf
fi
