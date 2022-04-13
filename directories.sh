#!zsh

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

echo -e "${C_GREEN}\nStarting Installation...$C_DEFAULT"

add_directory_in_home '.config'
add_directory_in_home '.ssh'
add_directory_in_home '.vim'
add_directory_in_home '.vim_swap'
add_directory_in_home '.bin'
