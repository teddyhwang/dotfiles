#!/bin/zsh

if [ -d /src/github.com/Shopify/shopify ]; then
  mkdir /src/github.com/Shopify/shopify/.vim
  cp coc-settings-sorbet.json /src/github.com/Shopify/shopify/.vim/coc-settings.json
elif [ -d /src/github.com/Shopify/shopify-dev ]; then
  mkdir /src/github.com/Shopify/shopify-dev/.vim
  cp coc-settings-solargraph.json /src/github.com/shopify/shopify-dev/.vim/coc-settings.json
fi

sudo npm install -g prettier || true

gpgconf --launch dirmngr
gpg --keyserver keys.openpgp.org --recv 5E3F0946116DFD4C553BEB5CCC211E2E2092D7C3

nvim --headless +PlugInstall +qall
timeout 1m nvim --headless +CocInstall || true
timeout 20s nvim --headless +CocInstall || true
