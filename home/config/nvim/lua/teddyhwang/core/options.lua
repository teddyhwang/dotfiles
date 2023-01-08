vim.opt.list = true
vim.opt.listchars = {
  trail = "⋅",
  tab = "›-",
}

vim.opt.colorcolumn = "80,120"

vim.opt.relativenumber = true
vim.opt.number = true

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.autoindent = true

vim.opt.wrap = false

vim.opt.ignorecase = false
vim.opt.smartcase = false

vim.opt.cursorline = true

vim.opt.termguicolors = true
vim.opt.background = "dark"
vim.opt.signcolumn = "yes"

vim.opt.backspace = "indent,eol,start"

vim.opt.clipboard:append("unnamedplus")

vim.opt.splitright = false
vim.opt.splitbelow = false

vim.opt.iskeyword:append("-")
