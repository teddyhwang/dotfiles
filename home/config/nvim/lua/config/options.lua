-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.mapleader = "\\"
vim.g.maplocalleader = "\\"

local opt = vim.opt

opt.colorcolumn = "80,120"
opt.cursorline = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.number = true
opt.relativenumber = true
opt.scrolloff = 3
opt.signcolumn = "yes"
opt.splitbelow = false
opt.splitright = false
opt.timeoutlen = 300
opt.updatetime = 100
opt.wrap = false

opt.listchars = {
  trail = "⋅",
  tab = "›-",
}

opt.foldenable = false
opt.foldlevel = 2
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldnestmax = 10

opt.iskeyword:append("-")
opt.sessionoptions:append("globals")

-- Diagnostics configuration
vim.diagnostic.config({
  virtual_text = true,
  virtual_lines = false,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

vim.treesitter.language.register("bash", "zsh")
