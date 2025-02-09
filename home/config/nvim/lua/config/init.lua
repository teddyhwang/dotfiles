local command_aliases = {
  WQ = "wq",
  Wq = "wq",
  Wa = "wa",
  W = "w",
  Q = "q",
  Qa = "qa",
  Ex = "Oil %:p:h",
  Vs = "vs",
  Vex = "vs | Oil %:p:h",
  VEx = "vs | Oil %:p:h",
  Se = "sp | Oil %:p:h",
  Sex = "sp | Oil %:p:h",
  SEx = "sp | Oil %:p:h",
  Tabe = "tabe",
  Irb = "FloatermNew irb",
  Lazygit = "FloatermNew lazygit",
  Node = "FloatermNew node",
  Python = "FloatermNew python",
  Yazi = "FloatermNew yazi",
  Terminal = "FloatermNew",
}

for alias, cmd in pairs(command_aliases) do
  vim.api.nvim_create_user_command(alias, cmd, {})
end

vim.g["mapleader"] = "\\"

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
vim.opt.mouse = "a"
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
vim.opt.updatetime = 100
vim.opt.wrap = false
vim.opt.wrap = false

vim.api.nvim_create_autocmd("VimResized", {
  pattern = "*",
  callback = function()
    vim.cmd("wincmd =")
  end,
})

vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "term://*",
  command = "startinsert",
})

vim.filetype.add({
  extension = {
    rbi = 'ruby',
    graphql = 'graphql',
    jsx = 'javascript.jsx',
    plist = 'xml',
    ejson = 'json',
  },
  pattern = {
    ['.*%.shared%.gitconfig'] = 'gitconfig',
  },
})

vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
  pattern = "*",
  callback = function()
    if vim.fn.mode() ~= "c" and vim.bo.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})
