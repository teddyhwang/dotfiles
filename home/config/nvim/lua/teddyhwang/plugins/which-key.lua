local whichkey_status, whichkey = pcall(require, "which-key")

if not whichkey_status then
  return
end

local function tmuxSplitCommand()
  vim.ui.input({
    prompt = "Command: ",
  }, function(input)
    if input then
      vim.cmd(string.format(":VimuxRunCommand '%s'", input))
    else
      vim.cmd("echo ''")
    end
  end)
end

local function search()
  vim.ui.input({
    prompt = "Search: ",
  }, function(input)
    if input then
      vim.cmd(string.format(":Rg %s", input))
    else
      vim.cmd("echo ''")
    end
  end)
end

whichkey.setup({
  triggers_blacklist = {
    n = { "y", "v", "d" },
    i = { "j", "k" },
  },
})
whichkey.register({
  ["!"] = { tmuxSplitCommand, "Run split command in tmux terminal" },
  ["+"] = { "<C-a>", "Increment number" },
  ["-"] = { "<C-x>", "Decrement number" },
  f = {
    b = { "<cmd>Telescope buffers<CR>", "Telescope buffersj" },
    c = { "<cmd>Telescope grep_string<CR>", "Telescope grep string" },
    f = { ":Fzf<CR>", "fzf" },
    g = { ":Lazygit<CR>", "lazygit" },
    h = { "<cmd>Telescope help_tags<CR>", "Telescope help tags" },
    n = { ":Node<CR>", "node" },
    p = { ":Python<CR>", "python" },
    r = { ":Ranger<CR>", "ranger" },
    R = { ":Irb<CR>", "irb" },
    s = { "<cmd>Telescope live_grep<CR>", "Telescope live grep" },
    t = { ":Terminal<CR>", "terminal" },
  },
  b = { "<cmd>Telescope git_branches<CR>", "Telescope git branches" },
  e = { ":NvimTreeFindFileToggle<CR>", "Toggle nvim tree" },
  E = { ":NvimTreeFindFile<CR>", "Find current file in nvim tree" },
  g = {
    c = { "<cmd>Telescope git_commits<CR>", "Telescope git commits" },
    fc = { "<cmd>Telescope git_bcommits<CR>", "Telescope git bcommits" },
    s = { "<cmd>Telescope git_status<CR>", "Telescope git status" },
  },
  l = { ":VimuxRunLastCommand<CR>", "Run last command in tmux" },
  O = { ":! open %:h<CR>", "Open file in Finder (Mac)" },
  q = { ":q<CR>", "Close current buffer" },
  t = {
    e = { "!TestNearest<CR>", "Test nearest" },
    n = { ":tabn<CR>", "Go to next tab" },
    o = { ":tabnew<CR>", "Open new tab" },
    p = { ":tabp<CR>", "Go to previous tab" },
    x = { ":tabclose<CR>", "Close current tab" },
  },
  T = { ":VimuxRunCommand 'dev test '.@%<CR>", "Test current file" },
  V = { "ggVG<CR>", "Visually select current buffer" },
  v = { ":e ~/.config/nvim/init.lua<CR>", "Edit init.luar" },
  y = { ":%y+<CR>", "Yank current file" },
}, { prefix = "<leader>" })

whichkey.register({
  ["<C-f>"] = { search, "Search" },
  [",ff"] = { ":Rg <C-R><C-W><CR>", "Search current text" },
  ["<C-t>"] = { ":Files<CR>", "Files" },
  ["<BS>"] = { ":noh<CR>:echo ''<CR>", "Clear search and messages" },
  [">"] = { "<C-w>20l", "Focus far right pane" },
  ["<"] = { "<C-w>20h", "Focus far left pane" },
  ["<C-p>"] = { "<cmd>Telescope find_files hidden=true<CR>", "Find files" },
})

whichkey.register({
  ["<C-j>"] = { "<cmd>lua require'luasnip'.jump(1)<CR>", "Luasnip scroll down" },
  ["<C-k>"] = { "<cmd>lua require'luasnip'.jump(-1)<CR>", "Luasnip scroll up" },
}, { mode = "i" })

whichkey.register({
  ["<C-j>"] = { "<cmd>lua require'luasnip'.jump(1)<CR>", "Luasnip scroll down" },
  ["<C-k>"] = { "<cmd>lua require'luasnip'.jump(-1)<CR>", "Luasnip scroll up" },
}, { mode = "s" })
