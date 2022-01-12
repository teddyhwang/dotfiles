#!/bin/zsh

if [ -d ~/src/github.com/Shopify/shopify ]; then
  mkdir ~/src/github.com/Shopify/shopify/.vim
  cp coc-settings-sorbet.json ~/src/github.com/Shopify/shopify/.vim/coc-settings.json
elif [ -d ~/src/github.com/Shopify/shopify-dev ]; then
  mkdir ~/src/github.com/Shopify/shopify-dev/.vim
  cp coc-settings-solargraph.json ~/src/github.com/shopify/shopify-dev/.vim/coc-settings.json
fi

gpgconf --launch dirmngr
gpg --keyserver keys.openpgp.org --recv 2CB89230F6B59B0B6785E8CE7C4CBAFEDC5B3117
git config --global user.signingkey 7C4CBAFEDC5B3117

nvim --headless +PlugInstall +qall
timeout 1m nvim --headless +CocInstall || true
timeout 20s nvim --headless +CocInstall || true
