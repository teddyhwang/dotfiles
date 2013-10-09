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
set statusline=%<\ %n:%f\ %m%r%y%=%-35.(line:\ %l\ of\ %L,\ col:\ %c%V\ (%P)%)
set backspace=indent,eol,start

set list listchars=tab:..,trail:-,nbsp:%
set clipboard=unnamed
set omnifunc=syntaxcomplete#Complete

set foldmethod=indent
set foldnestmax=10
set nofoldenable
set foldlevel=1

colo distinguished

" Do not wrap html files
autocmd FileType html set tw=0
autocmd FileType py set tw=0
autocmd FileType xhtml set tw=0
autocmd FileType htmldjango set tw=0
autocmd WinEnter * setlocal cursorline
autocmd WinLeave * setlocal nocursorline

" To turn off gitgutter
" let g:gitgutter_enabled = 0
let g:pyindent_open_paren = '&sw'
let g:pyindent_nested_paren = '&sw'
let g:pyindent_continue = '&sw'

au BufNewFile,BufReadPost *.py setl shiftwidth=4 sts=4 tabstop=4 expandtab
