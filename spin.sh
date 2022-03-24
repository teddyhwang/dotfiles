#!/bin/zsh

if [ -d ~/src/github.com/Shopify/shopify ]; then
  if ! [ -d ~/src/github.com/Shopify/shopify.vim ]; then
    mkdir ~/src/github.com/Shopify/shopify/.vim
  fi
  if ! [ -f ~/src/github.com/Shopify/shopify/.vim/coc-settings.json ]; then
    cp coc-settings-sorbet.json ~/src/github.com/Shopify/shopify/.vim/coc-settings.json
  fi
elif [ -d ~/src/github.com/Shopify/shopify-dev ]; then
  if ! [ -d ~/src/github.com/Shopify/shopify-dev/.vim ]; then
    mkdir ~/src/github.com/Shopify/shopify-dev/.vim
  fi
  if ! [ -f ~/src/github.com/shopify/shopify-dev/.vim/coc-settings.json ]; then
    cp coc-settings-solargraph.json ~/src/github.com/shopify/shopify-dev/.vim/coc-settings.json
  fi
fi

gpgconf --launch dirmngr
gpg --keyserver keys.openpgp.org --recv 2CB89230F6B59B0B6785E8CE7C4CBAFEDC5B3117
git config --global user.signingkey 7C4CBAFEDC5B3117

if ! [ $SSH_CLIENT ]; then
  nvim --headless +PlugInstall +qall
  timeout 1m nvim --headless +CocInstall || true
  timeout 20s nvim --headless +CocInstall || true
fi
