#!/bin/zsh

if [ -d /src/github.com/shopify/shopify ]; then
  mkdir /src/github.com/shopify/shopify/.vim
  cp coc-settings-sorbet.json /src/github.com/shopify/shopify/.vim/coc-settings.json
elif [ -d /src/github.com/shopify/shopify-dev ]; then
  mkdir /src/github.com/shopify/shopify-dev/.vim
  cp coc-settings-solargraph.json /src/github.com/shopify/shopify-dev/.vim/coc-settings.json
  cd /src/github.com/shopify/shopify-dev/
  bundle config set --local with 'solargraph' && bundle && bundle exec solargraph bundle
  cd -
else
  gem install solargraph && solargraph bundle
fi

gem install gem-ripper-tags && gem ripper_tags || true
sudo npm install -g prettier || true

stop && start && tmux source ~/.tmux.conf 

gpgconf --launch dirmngr
gpg --keyserver keys.openpgp.org --recv 5E3F0946116DFD4C553BEB5CCC211E2E2092D7C3

nvim --headless +PlugInstall +qall
timeout 1m nvim --headless +CocInstall || true
timeout 20s nvim --headless +CocInstall || true
