#!/usr/bin/zsh

C_DEFAULT="\x1B[39m"
C_GREEN="\x1B[32m"
C_LIGHTGRAY="\x1B[90m"

if [ -d ~/src/github.com/Shopify/shopify ]; then
  if ! [ -d ~/src/github.com/Shopify/shopify.vim ]; then
    mkdir ~/src/github.com/Shopify/shopify/.vim
  fi
  if ! [ -f ~/src/github.com/Shopify/shopify/.vim/coc-settings.json ]; then
    cp coc-settings-sorbet.json ~/src/github.com/Shopify/shopify/.vim/coc-settings.json
    cd ~/src/github.com/Shopify/shopify/ && gem install gem-ripper-tags && cd -
    source ~/.zshrc
    start_tmux shopify
  fi
fi

if [ -d ~/src/github.com/Shopify/shopify-dev ]; then
  if ! [ -d ~/src/github.com/Shopify/shopify-dev/.vim ]; then
    mkdir ~/src/github.com/Shopify/shopify-dev/.vim
  fi
  if ! [ -f ~/src/github.com/Shopify/shopify-dev/.vim/coc-settings.json ]; then
    cp coc-settings-solargraph.json ~/src/github.com/Shopify/shopify-dev/.vim/coc-settings.json
    cd ~/src/github.com/Shopify/shopify-dev/ && set_solargraph_bundle && bundle && gem install gem-ripper-tags cd -
    source ~/.zshrc
    start_tmux shopify-dev
  fi
fi

if git config --get-all user.signingkey | grep -q 7C4CBAFEDC5B3117; then
  echo -e "${C_LIGHTGRAY}\nGit signing key already configured$C_DEFAULT"
else
  gpgconf --launch dirmngr
  gpg --keyserver keys.openpgp.org --recv 2CB89230F6B59B0B6785E8CE7C4CBAFEDC5B3117
  git config --global user.signingkey 7C4CBAFEDC5B3117
fi

if ! [ $SSH_CLIENT ]; then
  nvim --headless +PlugInstall +qall
fi
