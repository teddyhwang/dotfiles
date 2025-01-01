#!/bin/zsh

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/print.sh"

if ! command -v overmind &> /dev/null; then
  go install github.com/DarthSim/overmind@latest
fi

if git config --get-all user.signingkey | grep -q 7C4CBAFEDC5B3117; then
  print_info "Git signing key already configured"
else
  gpgconf --launch dirmngr
  gpg --keyserver keys.openpgp.org --recv 2CB89230F6B59B0B6785E8CE7C4CBAFEDC5B3117
  git config --global user.signingkey 7C4CBAFEDC5B3117
fi

if ! [ $SSH_CLIENT ]; then
  timeout 2m nvim --headless "+Lazy! sync" +qa || true
fi

if [ -f /etc/spin/secrets/copilot_hosts.json ]; then
  mkdir -p "${HOME}/.config/github-copilot"
  cp /etc/spin/secrets/copilot_hosts.json "${HOME}/.config/github-copilot/hosts.json"
fi

echo -en '\x10' | sudo dd of=/usr/bin/gzip count=1 bs=1 conv=notrunc seek=$((0x189))
