local whichkey_status, whichkey = pcall(require, "which-key")

if not whichkey_status then
  return
end

whichkey.setup({
  defer = function(ctx)
    if vim.list_contains({ "d", "y" }, ctx.operator) then
      return true
    end
    return vim.list_contains({ "<C-V>", "V", "v" }, ctx.mode)
  end,
})
whichkey.add({
  {
    "<leader>!",
    function()
      vim.ui.input({
        prompt = "Command: ",
      }, function(input)
        if input then
          vim.cmd(string.format(":VimuxRunCommand '%s'", input))
        else
          vim.cmd("echo ''")
        end
      end)
    end,
    desc = "Run split command in tmux terminal",
  },
  { "<leader>+", "<C-a>", desc = "Increment number" },
  { "<leader>-", "<C-x>", desc = "Decrement number" },
  { "<leader>E", ":NvimTreeFindFile<CR>", desc = "Find current file in nvim tree" },
  { "<leader>O", ":! open %:h<CR>", desc = "Open file in Finder (Mac)" },
  { "<leader>T", ":VimuxRunCommand 'dev test '.@%<CR>", desc = "Test current file" },
  { "<leader>V", "ggVG<CR>", desc = "Visually select current buffer" },
  { "<leader>Y", ":%y+<CR>", desc = "Yank current file" },
  { "<leader>b", "<cmd>Telescope git_branches<CR>", desc = "Telescope git branches" },
  { "<leader>e", ":NvimTreeFindFileToggle<CR>", desc = "Toggle nvim tree" },
  { "<leader>fR", ":Irb<CR>", desc = "irb" },
  { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Telescope buffersj" },
  { "<leader>fc", "<cmd>Telescope grep_string<CR>", desc = "Telescope grep string" },
  { "<leader>ff", ":Fzf<CR>", desc = "fzf" },
  { "<leader>fg", ":Lazygit<CR>", desc = "lazygit" },
  { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Telescope help tags" },
  { "<leader>fn", ":Node<CR>", desc = "node" },
  { "<leader>fp", ":Python<CR>", desc = "python" },
  { "<leader>fr", ":Ranger<CR>", desc = "ranger" },
  { "<leader>fs", "<cmd>Telescope live_grep<CR>", desc = "Telescope live grep" },
  { "<leader>ft", ":Terminal<CR>", desc = "terminal" },
  { "<leader>gB", "<cmd>GitLink! blame<cr>", desc = "Open git blame link in browser" },
  { "<leader>gL", "<cmd>GitLink!<cr>", desc = "Open git permlink in browser" },
  { "<leader>gb", "<cmd>GitLink blame<cr>", desc = "Copy git blame link to clipboard" },
  { "<leader>gc", "<cmd>Telescope git_commits<CR>", desc = "Telescope git commits" },
  { "<leader>gfc", "<cmd>Telescope git_bcommits<CR>", desc = "Telescope git bcommits" },
  { "<leader>gl", "<cmd>GitLink<cr>", desc = "Copy git permlink to clipboard" },
  { "<leader>gs", "<cmd>Telescope git_status<CR>", desc = "Telescope git status" },
  { "<leader>l", ":VimuxRunLastCommand<CR>", desc = "Run last command in tmux" },
  { "<leader>q", ":q<CR>", desc = "Close current buffer" },
  { "<leader>te", "!TestNearest<CR>", desc = "Test nearest" },
  { "<leader>tn", ":tabn<CR>", desc = "Go to next tab" },
  { "<leader>to", ":tabnew<CR>", desc = "Open new tab" },
  { "<leader>tp", ":tabp<CR>", desc = "Go to previous tab" },
  { "<leader>tx", ":tabclose<CR>", desc = "Close current tab" },
  { "<leader>v", ":e ~/.config/nvim/init.lua<CR>", desc = "Edit init.luar" },
  { ",ff", ":Rg <C-R><C-W><CR>", desc = "Search current text" },
  { "<", "<C-w>20h", desc = "Focus far left pane" },
  { "<BS>", ":noh<CR>:echo ''<CR>", desc = "Clear search and messages" },
  {
    "<C-f>",
    function()
      vim.ui.input({
        prompt = "Search: ",
      }, function(input)
        if input then
          vim.cmd(string.format(":Rg %s", input))
        else
          vim.cmd("echo ''")
        end
      end)
    end,
    desc = "Search",
  },
  { "<C-p>", "<cmd>Telescope find_files hidden=true<CR>", desc = "Find files" },
  { "<C-t>", ":Files<CR>", desc = "Files" },
  { ">", "<C-w>20l", desc = "Focus far right pane" },
  { "<C-j>", "<cmd>lua require'luasnip'.jump(1)<CR>", desc = "Luasnip scroll down", mode = "i" },
  { "<C-k>", "<cmd>lua require'luasnip'.jump(-1)<CR>", desc = "Luasnip scroll up", mode = "i" },
  { "<C-j>", "<cmd>lua require'luasnip'.jump(1)<CR>", desc = "Luasnip scroll down", mode = "s" },
  { "<C-k>", "<cmd>lua require'luasnip'.jump(-1)<CR>", desc = "Luasnip scroll up", mode = "s" },
})
