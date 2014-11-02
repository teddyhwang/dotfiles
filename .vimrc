set nocompatible

" Pathogen
call pathogen#infect()
call pathogen#incubate()
syntax on "Enable syntax highlight
filetype plugin indent on " autoindent while editing according to the syntax

set bg=dark
set scrolloff=3
" set spell
set expandtab             " Converts tab keypresses to spaces
set hlsearch
set showmatch
set incsearch
set autoindent
set history=1000
set tabstop=2             " Number of spaces that a <Tab> count for
set shiftwidth=2          " Sets number of spaces used for (auto)indent
set sts=2                 " Number of spaces deleted when you hit <BS>
set tw=80
set cpoptions+=$
set nu
set directory^=$HOME/.vim_swap//   "put all swap files together in one place
set cursorline
" set statusline=%<\ %n:%f\ %m%r%y%=%-35.(line:\ %l\ of\ %L,\ col:\ %c%V\ (%P)%)
" set statusline=[r%{HGRev()}] 
set backspace=indent,eol,start

set list listchars=tab:..,trail:-,nbsp:%
set clipboard=unnamed
set omnifunc=syntaxcomplete#Complete

" set foldmethod=indent
set foldnestmax=10
set nofoldenable
set foldlevel=1

set colorcolumn=80

let g:gundo_close_on_revert=1

set rtp+=~/.vim/bundle/powerline/powerline/bindings/vim
set laststatus=2

highlight ColorColumn ctermbg=235 guibg=#2c2d27
let &colorcolumn="80,".join(range(120,999),",")

set tags=tags;/

colo distinguished

nnoremap <C-U> :GundoToggle<CR>

" Do not wrap html files
autocmd FileType html set tw=0
autocmd FileType py set tw=0
autocmd FileType xhtml set tw=0
autocmd FileType htmldjango set tw=0
autocmd WinEnter * setlocal cursorline
autocmd WinLeave * setlocal nocursorline

" To turn off gitgutter
" let g:gitgutter_enabled = 0
let g:syntastic_check_on_open=1
let g:syntastic_enable_signs=1
let g:syntastic_html_tidy_ignore_errors=[" proprietary attribute \"ng-"]
let g:syntastic_mode_map={ 'mode': 'active',
                     \ 'active_filetypes': [],
                     \ 'passive_filetypes': ['html'] }

au BufRead,BufNewFile *.cfg set filetype=python
au BufRead,BufNewFile *.cfg setl shiftwidth=4 sts=4 tabstop=4 expandtab
au BufNewFile,BufReadPost *.py setl shiftwidth=4 sts=4 tabstop=4 expandtab
au BufNewFile,BufReadPost *.coffee setl shiftwidth=2 sts=2 tabstop=2 expandtab

set wildignore+=*/dist/*,*/coverage_report/*,*/node_modules/*,*/bower_components/*,*.pyc,Session.vim,tags

let g:ctrlp_custom_ignore = {
  \ 'dir':  '\v[\/]\.(git|hg|svn)$',
  \ 'file': '\v\.(exe|so|dll|DS_Store|js|pyc)$',
  \ }

nmap <F8> :TagbarToggle<CR>
map <C-\> :tab split<CR>:exec("tag ".expand("<cword>"))<CR>
map <C-n> :tnext<CR>
map <C-b> :tprevious<CR>
