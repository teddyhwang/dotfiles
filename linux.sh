#!/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"
C_YELLOW="\x1B[33m"

if command -v apk &> /dev/null; then
  PKG_MANAGER="apk"
  PKG_INSTALL="apk add"
elif command -v apt-get &> /dev/null; then
  PKG_MANAGER="apt-get"
  PKG_INSTALL="apt-get install -y"
elif command -v dnf &> /dev/null; then
  PKG_MANAGER="dnf"
  PKG_INSTALL="dnf install -y"
elif command -v yum &> /dev/null; then
  PKG_MANAGER="yum"
  PKG_INSTALL="yum install -y"
elif command -v pacman &> /dev/null; then
  PKG_MANAGER="pacman"
  PKG_INSTALL="pacman -S --noconfirm"
else
  echo "No supported package manager found"
  exit 1
fi

touch ~/.z

echo -e "${C_GREEN}Installing system packages...$C_DEFAULT"
case $PKG_MANAGER in
  "apk")
    $PKG_INSTALL \
      bat \
      build-base \
      ctags \
      fd \
      fzf \
      git \
      gzip \
      highlight \
      py3-pip \
      python3 \
      ranger \
      ruby \
      ruby-dev \
      rust \
      tmux \
      xdg-utils

    if command -v batcat &> /dev/null && ! command -v bat &> /dev/null; then
      ln -s $(which batcat) /usr/local/bin/bat
    fi

    if ! command -v atuin &> /dev/null; then
      if command -v cargo &> /dev/null; then
        cargo install atuin
      else
        echo -e "${C_YELLOW}Cargo not found. Please ensure Rust is properly installed.$C_DEFAULT"
      fi
    else
      echo -e "${C_LIGHTGRAY}atuin already installed$C_DEFAULT"
    fi
    ;;

  *)
    if ! command -v brew &> /dev/null; then
      echo -e "${C_GREEN}Installing Homebrew...$C_DEFAULT"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      if [[ $(uname -m) == "x86_64" ]]; then
        BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"
      else
        BREW_BIN="/opt/homebrew/bin/brew"
      fi

      echo -e "${C_GREEN}Installing Brew packages...$C_DEFAULT"
      $BREW_BIN install tmux git-delta fzf bat fd ranger universal-ctags gzip atuin
      $($BREW_BIN --prefix)/opt/fzf/install --all
    else
      echo -e "${C_LIGHTGRAY}Brew already installed$C_DEFAULT"
    fi

    case $PKG_MANAGER in
      "apt-get")
        $PKG_INSTALL xdg-utils highlight fd-find
        ;;
      "dnf"|"yum")
        $PKG_INSTALL xdg-utils highlight fd
        ;;
      "pacman")
        $PKG_INSTALL xdg-utils highlight fd
        ;;
    esac
    ;;
esac

if command -v pip &> /dev/null || command -v pip3 &> /dev/null; then
  PIP_CMD=$(command -v pip3 || command -v pip)
  echo -e "${C_YELLOW}Installing Python packages globally. Consider using a virtual environment instead.$C_DEFAULT"
  $PIP_CMD install --break-system-packages neovim mycli || {
    echo -e "${C_YELLOW}Failed to install globally. Creating a virtual environment...$C_DEFAULT"
    python3 -m venv ~/.local/pipx/venv
    source ~/.local/pipx/venv/bin/activate
    $PIP_CMD install neovim mycli
  }
else
  echo "pip not found. Please install Python and pip first."
fi

if command -v gem &> /dev/null; then
  gem install gem-ripper-tags
else
  echo "gem not found. Please install Ruby first."
fi
