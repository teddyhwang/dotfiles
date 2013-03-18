set nocompatible
" Pathogen
call pathogen#infect()
call pathogen#helptags()

set bg=dark
set scrolloff=3
" set spell
set expandtab             " Converts tab keypresses to spaces
set hlsearch
set showmatch
set incsearch
set autoindent
set history=1000
set tabstop=4             " Number of spaces that a <Tab> count for
set shiftwidth=4          " Sets number of spaces used for (auto)indent
set sts=4                 " Number of spaces deleted when you hit <BS>
set tw=80
set cpoptions+=$
set nu
set directory^=$HOME/.vim_swap//   "put all swap files together in one place
set cursorline
set statusline=%<\ %n:%f\ %m%r%y%=%-35.(line:\ %l\ of\ %L,\ col:\ %c%V\ (%P)%)
set list listchars=tab:..,trail:-,nbsp:%
" Highlight Tabs, trailing spaces and non breakable-spaces
" Old tabs format:
" set list listchars=tab:>-,trail:-,nbsp:%

syntax enable             "Enable syntax highlight

colo ir_black

hi clear SpellBad
hi SpellBad cterm=underline

" Do not wrap html files
autocmd FileType html set tw=0
autocmd FileType xhtml set tw=0
autocmd FileType htmldjango set tw=0
autocmd WinEnter * setlocal cursorline
autocmd WinLeave * setlocal nocursorline

au BufNewFile,BufRead *.less set filetype=less
au BufRead,BufNewFile *.css set ft=css syntax=css3
au BufRead,BufNewFile jquery.*.js set ft=javascript syntax=jquery

highlight clear SignColumn

" To turn off gitgutter
" let g:gitgutter_enabled = 0
"
filetype plugin indent on " autoindent while editing according to the syntax

let g:pyindent_open_paren = '&sw'
let g:pyindent_nested_paren = '&sw'
let g:pyindent_continue = '&sw'
