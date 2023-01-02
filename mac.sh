#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

if ! [ -f ~/Library/Preferences/com.amethyst.Amethyst.plist ]; then
  echo -e "${C_GREEN}Copying Amethyst config file...$C_DEFAULT"
  cp -rf ./app_configs/com.amethyst.Amethyst.plist ~/Library/Preferences/com.amethyst.Amethyst.plist
else
  echo -e "${C_LIGHTGRAY}Amethyst config file is copied$C_DEFAULT"
fi

if ! [ -f ~/Library/Application\ Support/lazygit/config.yml ]; then
  echo -e "${C_GREEN}Copying lazygit config file...$C_DEFAULT"
  cp -rf ./app_configs/lazygit.config.yml ~/Library/Application\ Support/lazygit/config.yml
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
