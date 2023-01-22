vim.g.mapleader = "\\"

vim.opt.autoindent = true
vim.opt.autoread = true
vim.opt.background = "dark"
vim.opt.backspace = "indent,eol,start"
vim.opt.clipboard:append("unnamedplus")
vim.opt.colorcolumn = "80,120"
vim.opt.cursorline = true
vim.opt.expandtab = true
vim.opt.foldenable = false
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldlevel = 2
vim.opt.foldmethod = "expr"
vim.opt.foldnestmax = 10
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
vim.opt.timeout = true
vim.opt.timeoutlen = 300
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
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
  command = "if mode() != 'c' | checktime | endif",
  pattern = { "*" },
})
