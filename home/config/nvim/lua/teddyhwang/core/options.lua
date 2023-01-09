vim.opt.autoindent = true
vim.opt.background = "dark"
vim.opt.backspace = "indent,eol,start"
vim.opt.clipboard:append("unnamedplus")
vim.opt.colorcolumn = "80,120"
vim.opt.cursorline = true
vim.opt.expandtab = true
vim.opt.ignorecase = false
vim.opt.inccommand = "split"
vim.opt.iskeyword:append("-")
vim.opt.list = true
vim.opt.listchars = {
  trail = "⋅",
  tab = "›-",
}
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.scrolloff = 3
vim.opt.shiftwidth = 2
vim.opt.showmatch = true
vim.opt.signcolumn = "yes"
vim.opt.smartcase = false
vim.opt.splitbelow = false
vim.opt.splitright = false
vim.opt.tabstop = 2
vim.opt.termguicolors = true
vim.opt.ttyfast = true
vim.opt.tw = 120
vim.opt.wrap = false
vim.opt.wrap = false

vim.cmd("autocmd VimResized * wincmd =")
vim.cmd("autocmd TermOpen term://* startinsert")
vim.cmd("autocmd BufNewFile,BufRead *.rbi set filetype=ruby")
vim.cmd("autocmd BufNewFile,BufRead *.graphql set filetype=graphql")
vim.cmd("autocmd BufNewFile,BufRead *.jsx set filetype=javascript.jsx")
vim.cmd("autocmd BufNewFile,BufRead *.plist set filetype=xml")
vim.cmd("autocmd BufNewFile,BufRead *.ejson set filetype=json")
