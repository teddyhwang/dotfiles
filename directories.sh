#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

function add_directory_in_home {
  directory=$1
  if ! [ -d ~/$directory ]; then
    echo -e "${C_GREEN}Creating $directory folder...$C_DEFAULT"
    mkdir ~/$directory
  else
    echo -e "${C_LIGHTGRAY}$directory exists$C_DEFAULT"
  fi
}

add_directory_in_home '.config'
add_directory_in_home '.ssh'
add_directory_in_home '.bin'

if ! [ -d /usr/local/bin ]; then
  echo -e "${C_GREEN}Adding directory /usr/local/bin...$C_DEFAULT"
  sudo mkdir /usr/local/bin
else
  echo -e "${C_LIGHTGRAY}/usr/local/bin/ exists$C_DEFAULT"
fi

if ! [ -d ~/Library/Application\ Support/lazygit ]; then
  echo -e "${C_GREEN}Adding directory ~/Library/Application\ Support/lazygit...$C_DEFAULT"
  sudo mkdir ~/Library/Application\ Support/lazygit
else
  echo -e "${C_LIGHTGRAY}~/Library/Application\ Support/lazygit exists$C_DEFAULT"
fi

