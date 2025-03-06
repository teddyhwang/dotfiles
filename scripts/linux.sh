#!/bin/zsh

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/shared/print.sh"

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
  print_error "No supported package manager found"
  exit 1
fi

touch ~/.z

print_progress "Installing system packages..."
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
        print_warning "Cargo not found. Please ensure Rust is properly installed."
      fi
    else
      print_info "atuin already installed"
    fi
    ;;

  *)
    if ! command -v brew &> /dev/null; then
      print_success "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      if [[ $(uname -m) == "x86_64" ]]; then
        BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"
      else
        BREW_BIN="/opt/homebrew/bin/brew"
      fi

      print_success "Installing Brew packages..."
      $BREW_BIN install tmux git-delta fzf bat fd ranger universal-ctags gzip atuin
      $($BREW_BIN --prefix)/opt/fzf/install --all
      track_change
    else
      print_info "Brew already installed"
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
  print_warning "Installing Python packages globally. Consider using a virtual environment instead."
  $PIP_CMD install --break-system-packages neovim mycli || {
    print_warning "Failed to install globally. Creating a virtual environment..."
    python3 -m venv ~/.local/pipx/venv
    source ~/.local/pipx/venv/bin/activate
    $PIP_CMD install neovim mycli
  }
else
  print_error "pip not found. Please install Python and pip first."
fi

if command -v gem &> /dev/null; then
  gem install gem-ripper-tags
else
  print_error "gem not found. Please install Ruby first."
fi
