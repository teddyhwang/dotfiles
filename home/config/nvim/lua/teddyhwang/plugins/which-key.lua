return function(whichkey)
  local function smart_swap(direction)
    local current_win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(current_win)

    vim.cmd("wincmd " .. direction)
    local target_win = vim.api.nvim_get_current_win()

    if current_win ~= target_win then
      local current_buf = vim.api.nvim_win_get_buf(current_win)
      local target_buf = vim.api.nvim_win_get_buf(target_win)

      vim.api.nvim_win_set_buf(current_win, target_buf)
      vim.api.nvim_win_set_buf(target_win, current_buf)
    else
      vim.api.nvim_set_current_win(current_win)
      vim.cmd("close")

      if direction == "h" then
        vim.cmd("topleft vsplit")
      elseif direction == "l" then
        vim.cmd("botright vsplit")
      elseif direction == "k" then
        vim.cmd("topleft split")
      else
        vim.cmd("botright split")
      end

      vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
    end
  end

  local function search_prompt()
    vim.ui.input({
      prompt = "Search: ",
    }, function(input)
      if input then
        vim.cmd(string.format(":FzfLua grep search=%s", input))
      else
        vim.cmd("echo ''")
      end
    end)
  end

  local function run_tmux_command()
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
      run_tmux_command,
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
    { "<leader>fr", ":Yazi<cr>", desc = "yazi" },
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
    { "gr", ":Lspsaga finder<cr>", desc = "Find references" },
    { "gR", ":References<cr>", desc = "Show references" },
    { "gd", ":Lspsaga goto_definition<cr>", desc = "Go to definition" },
    { "gD", ":Lspsaga peek_definition<cr>", desc = "Peek definition" },
    { "<leader>ca", ":Lspsaga code_action<cr>", desc = "Code actions" },
    { "<leader>rn", ":Lspsaga rename<cr>", desc = "Rename symbol" },
    { "[d", ":Lspsaga diagnostic_jump_prev<cr>", desc = "Previous diagnostic" },
    { "]d", ":Lspsaga diagnostic_jump_next<cr>", desc = "Next diagnostic" },
    { "K", ":Lspsaga hover_doc<cr>", desc = "Show hover documentation" },
    { ",ff", ":FzfLua grep_cword<cr>", desc = "Search current text" },
    { "<", "<C-w>20h", desc = "Focus far left pane" },
    { ">", "<C-w>20l", desc = "Focus far right pane" },
    { "<BS>", ":noh<cr>:echo ''<cr>", desc = "Clear search and messages" },
    { "<C-f>", search_prompt, desc = "Search" },
    { '"', ":FzfLua registers<cr>", desc = "Show registers" },
    { "<C-p>", ":FzfLua files<cr>", desc = "Find files" },
    { "<C-t>", require("teddyhwang.plugins.fzf-lua").switch_windows, desc = "Switch between windows" },
    {
      "q:",
      ":FzfLua command_history<cr>",
      desc = "Command history window",
      mode = "n",
    },
    {
      "<C-j>",
      ":lua require'luasnip'.jump(1)<cr>",
      desc = "Luasnip scroll down",
      mode = "i",
    },
    {
      "<C-k>",
      ":lua require'luasnip'.jump(-1)<cr>",
      desc = "Luasnip scroll up",
      mode = "i",
    },
    {
      "<C-j>",
      ":lua require'luasnip'.jump(1)<cr>",
      desc = "Luasnip scroll down",
      mode = "s",
    },
    {
      "<C-k>",
      ":lua require'luasnip'.jump(-1)<cr>",
      desc = "Luasnip scroll up",
      mode = "s",
    },
    {
      "<C-w>H",
      function()
        smart_swap("h")
      end,
      desc = "Swap window left",
    },
    {
      "<C-w>J",
      function()
        smart_swap("j")
      end,
      desc = "Swap window down",
    },
    {
      "<C-w>K",
      function()
        smart_swap("k")
      end,
      desc = "Swap window up",
    },
    {
      "<C-w>L",
      function()
        smart_swap("l")
      end,
      desc = "Swap window right",
    },
  })
end
