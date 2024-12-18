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
  { "<leader>E", ":NvimTreeFindFile<cr>", desc = "Find current file in nvim tree" },
  { "<leader>O", ":! open %:h<cr>", desc = "Open file in Finder (Mac)" },
  { "<leader>T", ":VimuxRunCommand 'dev test '.@%<cr>", desc = "Test current file" },
  { "<leader>V", "ggVG<cr>", desc = "Visually select current buffer" },
  { "<leader>Y", ":%y+<cr>", desc = "Yank current file" },
  { "<leader>b", ":FzfLua git_branches<cr>", desc = "FzfLua git branches" },
  { "<leader>e", ":NvimTreeFindFileToggle<cr>", desc = "Toggle nvim tree" },
  { "<leader>fR", ":Irb<cr>", desc = "irb" },
  { "<leader>fb", ":FzfLua buffers<cr>", desc = "FzfLua buffersj" },
  { "<leader>fc", ":FzfLua grep_cWORD<cr>", desc = "FzfLua grep string" },
  { "<leader>ff", ":Fzf<cr>", desc = "fzf" },
  { "<leader>fg", ":Lazygit<cr>", desc = "lazygit" },
  { "<leader>fh", ":FzfLua help_tags<cr>", desc = "FzfLua help tags" },
  { "<leader>fn", ":Node<cr>", desc = "node" },
  { "<leader>fp", ":Python<cr>", desc = "python" },
  { "<leader>fr", ":Ranger<cr>", desc = "ranger" },
  { "<leader>fs", ":FzfLua live_grep<cr>", desc = "FzfLua live grep" },
  { "<leader>ft", ":Terminal<cr>", desc = "terminal" },
  { "<leader>gB", ":GitLink! blame<cr>", desc = "Open git blame link in browser" },
  { "<leader>gL", ":GitLink!<cr>", desc = "Open git permlink in browser" },
  { "<leader>gb", ":GitLink blame<cr>", desc = "Copy git blame link to clipboard" },
  { "<leader>gc", ":FzfLua git_commits<cr>", desc = "FzfLua git commits" },
  { "<leader>gfc", ":FzfLua git_bcommits<cr>", desc = "FzfLua git bcommits" },
  { "<leader>gl", ":GitLink<cr>", desc = "Copy git permlink to clipboard" },
  { "<leader>gs", ":FzfLua git_status<cr>", desc = "FzfLua git status" },
  { "<leader>l", ":VimuxRunLastCommand<cr>", desc = "Run last command in tmux" },
  { "<leader>q", ":q<cr>", desc = "Close current buffer" },
  { "<leader>te", "!TestNearest<cr>", desc = "Test nearest" },
  { "<leader>tn", ":tabn<cr>", desc = "Go to next tab" },
  { "<leader>to", ":tabnew<cr>", desc = "Open new tab" },
  { "<leader>tp", ":tabp<cr>", desc = "Go to previous tab" },
  { "<leader>tx", ":tabclose<cr>", desc = "Close current tab" },
  { "<leader>v", ":e ~/.config/nvim/init.lua<cr>", desc = "Edit init.luar" },
  -- { ",ff", ":Rg <C-R><C-W><cr>", desc = "Search current text" },
  { ",ff", ":FzfLua grep_cword<cr>", desc = "Search current text" },
  { "<", "<C-w>20h", desc = "Focus far left pane" },
  { "<BS>", ":noh<cr>:echo ''<CR>", desc = "Clear search and messages" },
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
  { "<C-p>", ":FzfLua files<cr>", desc = "Find files" },
  { "<C-t>", ":Files<cr>", desc = "Files" },
  { ">", "<C-w>20l", desc = "Focus far right pane" },
  { "<C-j>", ":lua require'luasnip'.jump(1)<cr>", desc = "Luasnip scroll down", mode = "i" },
  { "<C-k>", ":lua require'luasnip'.jump(-1)<cr>", desc = "Luasnip scroll up", mode = "i" },
  { "<C-j>", ":lua require'luasnip'.jump(1)<cr>", desc = "Luasnip scroll down", mode = "s" },
  { "<C-k>", ":lua require'luasnip'.jump(-1)<cr>", desc = "Luasnip scroll up", mode = "s" },
  { '"', ":FzfLua registers<cr>", desc = "Show registers" },
})
