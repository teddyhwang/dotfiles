syn on
set bg=dark
filetype plugin indent on " autoindent while editing according to the syntax
" our best practices requires only one level of indentation when wrapping lines
set scrolloff=3
let g:pyindent_open_paren = '&sw'
let g:pyindent_nested_paren = '&sw'
let g:pyindent_continue = '&sw'
set expandtab             " Converts tab keypresses to spaces
set tabstop=4             " Number of spaces that a <Tab> count for
set shiftwidth=4          " Sets number of spaces used for (auto)indent
set sts=4                 " Number of spaces deleted when you hit <BS>
set tw=80
" Highlight Tabs, trailing spaces and non breakable-spaces
" Old tabs format:
" set list listchars=tab:>-,trail:-,nbsp:%
set list listchars=tab:..,trail:-,nbsp:%
" Do not wrap html files
autocmd FileType html set tw=0
autocmd FileType xhtml set tw=0
autocmd FileType htmldjango set tw=0
syntax enable             "Enable syntax highlight
set cpoptions+=$
set nu
colo ir_black
au BufNewFile,BufRead *.less set filetype=less
au BufRead,BufNewFile *.css set ft=css syntax=css3
au BufRead,BufNewFile jquery.*.js set ft=javascript syntax=jquery
set directory^=$HOME/.vim_swap//   "put all swap files together in one place
set cursorline
" hi CursorLine   cterm=NONE ctermbg=darkgrey ctermfg=white guibg=darkgrey guifg=white
" hi CursorColumn cterm=NONE ctermbg=darkgrey ctermfg=white guibg=darkgrey guifg=white
" nnoremap <Leader>c :set cursorline! cursorcolumn!<CR>
autocmd WinEnter * setlocal cursorline
autocmd WinLeave * setlocal nocursorline
