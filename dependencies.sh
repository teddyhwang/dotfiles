#!/bin/zsh

set -e
set -u

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/print.sh"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin)
    source './mac.sh'
    ;;
  Linux)
    source './linux.sh'
    ;;
  *)
    print_error "Unsupported operating system: $OS"
    exit 1
    ;;
esac

if ! [ -f /usr/local/bin/cht.sh ]; then
  print_progress "Adding cht.sh..."
  wget -O /usr/local/bin/cht.sh https://cht.sh/:cht.sh || sudo wget -O /usr/local/bin/cht.sh https://cht.sh/:cht.sh
  chmod +x /usr/local/bin/cht.sh || sudo chmod +x /usr/local/bin/cht.sh
  track_change
else
  print_info "cht.sh exists"
fi

print_conditional_success "Dependencies"
