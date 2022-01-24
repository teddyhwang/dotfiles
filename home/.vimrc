if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
if executable('shadowenv')
  Plug 'Shopify/shadowenv.vim'
endif
Plug 'AndrewRadev/splitjoin.vim'
Plug 'AndrewRadev/undoquit.vim'
Plug 'airblade/vim-rooter'
Plug 'alvan/vim-closetag'
Plug 'andymass/vim-matchup'
Plug 'antoinemadec/coc-fzf'
Plug 'benmills/vimux'
Plug 'blueyed/vim-diminactive'
Plug 'chriskempson/base16-vim'
Plug 'dbeniamine/cheat.sh-vim'
Plug 'dense-analysis/ale'
Plug 'dhruvasagar/vim-table-mode'
Plug 'dhruvasagar/vim-zoom'
Plug 'iamcco/markdown-preview.nvim', {'do': 'cd app & yarn install'}
Plug 'jiangmiao/auto-pairs'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
Plug 'junegunn/vim-peekaboo'
Plug 'kana/vim-textobj-user'
Plug 'kristijanhusak/vim-carbon-now-sh'
Plug 'kristijanhusak/vim-dadbod-completion'
Plug 'kristijanhusak/vim-dadbod-ui'
Plug 'liuchengxu/vim-which-key'
Plug 'liuchengxu/vista.vim'
Plug 'ludovicchabant/vim-gutentags'
Plug 'machakann/vim-highlightedyank'
Plug 'matze/vim-move'
Plug 'mg979/vim-visual-multi', {'branch': 'master'}
Plug 'nelstrom/vim-textobj-rubyblock'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'prabirshrestha/async.vim'
Plug 'rbgrouleff/bclose.vim'
Plug 'ruanyl/vim-gh-line'
Plug 'sheerun/vim-polyglot'
Plug 'simeji/winresizer'
Plug 'tmux-plugins/vim-tmux'
Plug 'tpope/vim-bundler'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-dadbod'
Plug 'tpope/vim-dispatch'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-obsession'
Plug 'tpope/vim-rails'
Plug 'tpope/vim-rhubarb'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-sleuth'
Plug 'tpope/vim-surround'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'vim-scripts/Tabmerge'
Plug 'vim-test/vim-test'
Plug 'voldikss/vim-floaterm'
Plug 'whatyouhide/vim-tmux-syntax'
Plug 'xolox/vim-misc'
Plug 'zackhsi/sorbet.vim'
call plug#end()

setglobal complete-=i
set autoread
set backupdir=/tmp//
set clipboard+=unnamedplus
set cmdheight=1
set completeopt=menu
set cpoptions+=$
set cursorline
set directory=/tmp//
set directory^=$HOME/.vim_swap/
set expandtab
set exrc
set foldlevel=2
set foldmethod=indent
set foldnestmax=10
set hidden
set history=1000
set hlsearch
set incsearch
set laststatus=2
set lazyredraw
set list
set listchars=tab:›\ ,trail:⋅
set mouse=a
set nocursorcolumn
set nofoldenable
set nowrap
set redrawtime=10000
if !empty(glob('/usr/local/opt/fzf'))
  set rtp+=/usr/local/opt/fzf
endif
if !empty(glob('/opt/homebrew/opt/fzf'))
  set rtp+=/opt/homebrew/opt/fzf
endif
set scrolloff=3
set secure
set shiftwidth=2
set shortmess=aFc
set showmatch
set signcolumn=yes
set statusline+=%#warningmsg#
set statusline+=%*
set sts=2
set synmaxcol=0
set tabstop=2
set timeoutlen=500 ttimeoutlen=0
set ttyfast
set tw=120
set undodir=/tmp//
set updatetime=1000
set wildignore+=*/dist/*,*/coverage/*,*/coverage_report/*,*/node_modules/*,*.pyc,Session.vim,tags,*.git
if !empty(glob('~/.vim/plugged/vim-gutentags'))
  set statusline+=%{gutentags#statusline()}
endif
if has('nvim')
  set termguicolors
endif
if exists('&inccommand')
  set inccommand=split
endif

let base16colorspace = 256
let g:airline#extensions#vista#enabled = 0
let g:airline_section_error = '%{airline#util#wrap(airline#extensions#coc#get_error(),0)}'
let g:airline_section_warning = '%{airline#util#wrap(airline#extensions#coc#get_warning(),0)}'
let g:airline_theme = 'base16'
let g:ale_cache_executable_check_failures = 1
let g:ale_completion_enabled = 0
let g:ale_disable_lsp = 1
let g:ale_echo_msg_format = '[%linter% | %severity%] %s'
let g:ale_fix_on_save = 0
let g:ale_fixers = {
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'javascript': ['prettier'],
\   'ruby': ['rubocop'],
\}
let g:ale_lint_delay = 0
let g:ale_linters = {
  \ 'ruby': ['rubocop', 'ruby', 'sorbet'],
  \ 'graphql': ['gqlint'],
  \ }
let g:ale_ruby_rubocop_executable = 'bundle'
let g:ale_ruby_sorbet_options = '--ignore=test'
let g:ale_set_highlights = 0
let g:ale_sign_error = '◉'
let g:ale_sign_warning = '◉'
let g:closetag_filenames = '*.html,*.xhtml,*.phtml,*.jsx,*.tsx'
let g:closetag_filetypes = 'html,xhtml,phtml,jsx,tsx'
let g:closetag_xhtml_filenames = '*.xhtml,*.jsx,*.tsx'
let g:coc_fzf_preview = 'right:50%'
let g:coc_force_debug = 0
let g:coc_global_extensions = [
  \ 'coc-css',
  \ 'coc-db',
  \ 'coc-emoji',
  \ 'coc-eslint',
  \ 'coc-explorer',
  \ 'coc-git',
  \ 'coc-highlight',
  \ 'coc-html',
  \ 'coc-json',
  \ 'coc-marketplace',
  \ 'coc-python',
  \ 'coc-snippets',
  \ 'coc-solargraph',
  \ 'coc-syntax',
  \ 'coc-tag',
  \ 'coc-tslint-plugin',
  \ 'coc-tsserver',
  \ 'coc-yaml',
  \ 'coc-yank',
  \ 'https://github.com/karuna/vscode-rspec-snippets',
  \ 'https://github.com/infeng/vscode-react-typescript',
  \ ]
  " \ 'https://github.com/Chris56974/ruby-and-rails-snippets',
let g:coc_node_args = ['--dns-result-order=ipv4first']
if !empty(glob('/opt/homebrew/bin/node'))
  let g:coc_node_path = '/opt/homebrew/bin/node'
else
  let g:coc_node_path = '/usr/local/bin/node'
endif
let g:diminactive_use_colorcolumn = 1
let g:colorcolumn_supported_filetypes = [
  \ 'brewfile',
  \ 'css',
  \ 'eruby',
  \ 'gemfilelock',
  \ 'gitcommit',
  \ 'gitconfig',
  \ 'go',
  \ 'graphql',
  \ 'html',
  \ 'javascript',
  \ 'javascript.jsx',
  \ 'javascriptreact',
  \ 'json',
  \ 'jsonc',
  \ 'markdown',
  \ 'mysql',
  \ 'python',
  \ 'ruby',
  \ 'screen',
  \ 'scss',
  \ 'sh',
  \ 'sql',
  \ 'tmux',
  \ 'typescript',
  \ 'typescript.tsx',
  \ 'typescriptreact',
  \ 'xml',
  \ 'yaml',
  \ 'zsh',
  \ ]
let g:gitgutter_override_sign_column_highlight = 0
let g:indentLine_concealcursor = 'nc'
let g:move_key_modifier = 'C'
let g:closetag_xhtml_filetypes = 'xhtml,jsx,tsx'
let g:closetag_emptyTags_caseSensitive = 1
let g:closetag_regions = {
  \ 'typescript.tsx': 'jsxRegion,tsxRegion',
  \ 'javascript.jsx': 'jsxRegion',
  \ }
let g:disable_toggle_highlight = 0
let g:disable_relative_number = 0
let g:fzf_layout = { 'window': { 'width': 1, 'height': 0.4, 'yoffset': 1, 'border': 'horizontal' } }
let g:gutentags_define_advanced_commands = 1
let g:gutentags_exclude_filetypes = ['gitcommit', 'gitconfig', 'gitrebase', 'gitsendemail', 'git']
let g:highlightedyank_highlight_duration = 100
let g:dbs = {
\  'shopify': 'presto://presto-for-datachi.presto.tunnel.shopifykloud.com:8675'
\ }
let g:db_ui_use_nerd_fonts = 1
let g:db_ui_save_location = '~/src/queries'
let g:db_async = 1
let g:presto_url = 'presto://presto-for-datachi.presto.tunnel.shopifykloud.com:8675/hive'
let g:table_mode_corner='|'
let g:vista_default_executive = 'coc'
let g:winresizer_horiz_resize = 1
let g:winresizer_vert_resize = 3
let test#strategy = 'vimux'
let g:floaterm_autoclose = 1
let g:floaterm_gitcommit = 'floaterm'
let g:floaterm_height = 0.8
let g:floaterm_keymap_new  = '<F4>'
let g:floaterm_keymap_next = '<F2>'
let g:floaterm_keymap_prev = '<F3>'
let g:floaterm_keymap_toggle = '<F1>'
let g:floaterm_open_command = 'vsplit'
let g:floaterm_width = 0.8
if !empty(glob('~/Dropbox/Notes'))
  let g:notes_directories = ['~/Dropbox/Notes']
endif
let g:diminactive_filetype_blacklist = ['which_key']
let g:which_key_use_floating_win = 0
let g:which_key_map = {}
let g:which_key_map['i'] = [':Vista!!', 'vista']
let g:which_key_map['e'] = [':call WriteNewFile()', 'new file']
let g:which_key_map['n'] = [':call ToggleRelativeNumber(1)', 'toggle relativenumber']
let g:which_key_map['o'] = [':! open %:h', 'open file']
let g:which_key_map['r'] = [':source ~/.vimrc', 'reload vimrc']
let g:which_key_map['y'] = [':%y+', 'copy file']
let g:which_key_map['!'] = [':call TmuxSplitCommand()', 'run command']
let g:which_key_map['l'] = [':VimuxRunLastCommand', 'run last command']
let g:which_key_map['s'] = [':call FzfSpell()', 'spellcheck']
let g:which_key_map['V'] = ['ggVG', 'visual mode file']
let g:which_key_map['v'] = [':e ~/.vimrc', 'edit vimrc']
let g:which_key_map['d'] = [':%DB g:presto_url', 'run query']
let g:which_key_map['D'] = [':Dispatch presto --catalog hive --server presto-for-datachi.presto.tunnel.shopifykloud.com:8675 -f ./% --output-format ALIGNED', 'run query']
let g:which_key_map['t'] = [':TestNearest', 'test nearest']
let g:which_key_map['T'] = [":VimuxRunCommand 'dev test '.@%", 'test file'] " :TestFile
let g:which_key_map['f'] = {
  \ 'name' : '+floater' ,
  \ 't' : [':Terminal'  , 'terminal'],
  \ 'f' : [':Fzf'       , 'fzf'],
  \ 'g' : [':Lazygit'   , 'git'],
  \ 'n' : [':Node'      , 'node'],
  \ 'p' : [':Python'    , 'python'],
  \ 'r' : [':Ranger'    , 'ranger'],
  \ 'R' : [':Irb'       , 'irb'],
  \ }

command! Eslint CocCommand eslint.showOutputChannel
command! Fzf FloatermNew fzf
command! Irb FloatermNew irb
command! Lazygit FloatermNew lazygit
command! Node FloatermNew node
command! Python FloatermNew python
command! Ranger FloatermNew ranger
command! Terminal FloatermNew
command! WQ wq
command! Wq wq
command! Wa wa
command! W w
command! Q q
command! Qa qa
command! Vs vs
command! VEx vex
command! Tabe tabe
command! -nargs=* -bar -bang -count=0 -complete=dir Ex Explore <args>
command! -nargs=0 Prettier :CocCommand prettier.formatFile
command! -bar CloseFloats call s:close_floats()

inoremap <silent><expr> <TAB>
  \ pumvisible() ? "\<C-y>" :
  \ <SID>check_back_space() ? "\<TAB>" :
  \ coc#refresh()
inoremap <expr> <C-j> pumvisible() ? "\<C-n>" : "\<C-j>"
inoremap <expr> <C-k> pumvisible() ? "\<C-p>" : "\<C-k>"
inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<cr>"
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
nnoremap <silent> <leader> :WhichKey '\'<cr>
vnoremap <silent> <leader> :WhichKeyVisual '\'<cr>
nmap <leader><bs> :call ToggleHighlight(1)<cr>
nmap <leader>ca <Plug>(coc-codeaction)
nmap <leader>== <Plug>(coc-fix-current)
nmap <silent> <BS> :noh<cr>
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)
nmap <silent> ga :ALEGoToDefinition<cr>
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
nmap <silent> gs :ALEGoToDefinitionInSplit<cr>
nmap <silent> gv :ALEGoToDefinitionInVSplit<cr>
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> > <C-w>20l
nmap <silent> < <C-w>20h
nnoremap <nowait> <C-\> :CocCommand explorer<cr>
nnoremap ,ff :Rg <C-R><C-W><cr>
nnoremap <silent> <space>y  :<C-u>CocList -A --normal yank<cr>
nnoremap <silent> K :call <SID>show_documentation()<cr>
nnoremap <leader>gc :Gvdiffsplit!<cr>
nnoremap gch :diffget //2<cr>
nnoremap gcl :diffget //3<cr>
noremap <C-f> :call Search()<cr>
noremap <C-q> :Vista finder coc<cr>
noremap <C-p> :Files<cr>
noremap <C-t> :Rg<cr>
if has('nvim')
  tnoremap <Esc><Esc> <C-\><C-n>
endif

autocmd BufNewFile,BufRead *.tmuxtheme set filetype=tmux
autocmd BufNewFile,BufRead *.rbi set filetype=ruby
autocmd BufNewFile,BufRead *.graphql set filetype=graphql
autocmd BufNewFile,BufRead *.plist set syntax=xml
autocmd BufNewFile,BufRead ?\+.ejson setf json
autocmd CursorHold * call ToggleHighlight()
autocmd FileType ruby,eruby let g:gutentags_ctags_executable_ruby = 'ripper-tags'
autocmd FileType ruby,eruby let g:gutentags_ctags_extra_args = ['--ignore-unsupported-options', '--recursive']
autocmd FocusGained * :checktime
autocmd! FileType which_key
autocmd  FileType which_key set laststatus=0 noshowmode noruler
  \| autocmd BufLeave <buffer> set laststatus=2 showmode ruler

augroup MarkdownSpell
  autocmd!
  autocmd FileType markdown setlocal spell
  autocmd BufRead,BufNewFile *.md setlocal spell
augroup END
augroup PreviewAutocmds
  autocmd!
  autocmd BufEnter *.dbout if &previewwindow | setlocal nonumber norelativenumber colorcolumn= | endif
augroup END
augroup Numbertoggle
  autocmd!
  autocmd BufEnter,FocusGained,InsertLeave * if index(g:colorcolumn_supported_filetypes, &ft) > -1 && g:disable_relative_number == 0 | setlocal number relativenumber colorcolumn=80,120 | endif
  autocmd BufEnter,FocusGained,InsertLeave * if index(g:colorcolumn_supported_filetypes, &ft) > -1 && g:disable_relative_number == 1 | setlocal number norelativenumber colorcolumn=80,120 | endif
  autocmd BufLeave,FocusLost,InsertEnter   * if index(g:colorcolumn_supported_filetypes, &ft) > -1 | setlocal number norelativenumber colorcolumn=80,120 | endif
  autocmd BufEnter,FocusGained,InsertLeave *.vimrc if g:disable_relative_number == 0 | setlocal number relativenumber colorcolumn=80,120 | endif
  autocmd BufEnter,FocusGained,InsertLeave *.vimrc if g:disable_relative_number == 1 | setlocal number norelativenumber colorcolumn=80,120 | endif
  autocmd BufLeave,FocusLost,InsertEnter   *.vimrc setlocal number norelativenumber colorcolumn=80,120
  autocmd FileType floaterm setlocal colorcolumn=
augroup END
augroup CursorLine
  au!
  au VimEnter * setlocal cursorline
  au WinEnter * setlocal cursorline
  au BufWinEnter * setlocal cursorline
  au WinLeave * setlocal nocursorline
augroup END
autocmd VimResized * wincmd =
if has('nvim')
  autocmd TermOpen term://* startinsert
endif

if !empty($SPIN)
  source ~/.vim/remote.vim
endif

function! s:close_floats() abort
  for win in nvim_tabpage_list_wins(tabpagenr())
    if !empty(get(nvim_win_get_config(win), 'relative', ''))
      call nvim_win_close(win, v:true)
    endif
  endfor
endf

function! s:setup_color()
  silent! source ~/.vim/colorscheme.vim
  highlight SignColumn guibg=NONE
  highlight SpellBad  guibg=#Cd3f45 guifg=#13354A
  highlight WhichKeyFloating guibg=NONE
  highlight link ALEErrorSign WarningMsg
  highlight link ALEWarningSign Label
  highlight link CocErrorSign WarningMsg
  highlight link CocInfoSign Label
  highlight link CocWarningSign Label
  highlight link HighlightedyankRegion MatchParen
  highlight link Sig Comment
  highlight link SigBlockDelimiter Comment
endfunction

function! FzfSpellSink(word)
  exe 'normal! "_ciw'.a:word
endfunction

function! FzfSpell()
  let suggestions = spellsuggest(expand("<cword>"))
  return fzf#run({'source': suggestions, 'sink': function("FzfSpellSink"), 'down': 10 })
endfunction

function! ToggleRelativeNumber(...)
  if a:0 == 1
    let g:disable_relative_number = 1 - g:disable_relative_number
  endif

  if g:disable_relative_number == 0
    set number relativenumber
  else
    set number norelativenumber
  endif
endfunction

function! ToggleHighlight(...)
  if a:0 == 1
    let g:disable_toggle_highlight = 1 - g:disable_toggle_highlight
  endif

  if g:disable_toggle_highlight == 0
    silent! call CocActionAsync('highlight')
  endif
endfunction

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

function! s:show_documentation()
  if &filetype == 'vim'
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

function! WriteNewFile()
  let l:filename = input('Enter filename: ')
  if l:filename != ''
    execute 'e %:h/'.l:filename
  endif
endf

function! Search()
  let l:search = input('Search: ')
  if l:search != ''
    execute ':Rg '.l:search
  endif
endf

function! TmuxSplitCommand()
  let l:command = input('Run command: ')
  if l:command != ''
    execute ':VimuxRunCommand "'.l:command.'"'
  endif
endf

call s:setup_color()
silent! call which_key#register('\', "g:which_key_map")
