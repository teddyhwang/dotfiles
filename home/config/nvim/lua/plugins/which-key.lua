return {
  "folke/which-key.nvim",
  dependencies = {
    "folke/snacks.nvim",
    "akinsho/toggleterm.nvim",
  },
  opts = function()
    local whichkey = require("which-key")
    local windows = require("windows")
    local Snacks = require("snacks")
    local Terminal = require("toggleterm.terminal").Terminal
    local flash = require("flash")

    local yazi = Terminal:new({
      cmd = "yazi",
      direction = "float",
      float_opts = {
        border = "curved",
        winblend = 0,
      },
      highlights = {
        FloatBorder = {
          link = "FloatBorder",
        },
      },
      on_open = function(term)
        vim.cmd("startinsert!")
        vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
      end,
      on_close = function()
        vim.cmd("startinsert!")
      end,
    })

    local function toggle_yazi()
      local bufpath = vim.fn.expand("%:p:h")
      yazi.dir = bufpath ~= "" and bufpath or vim.fn.getcwd()
      yazi:toggle()
    end

    local search_prompt = function()
      vim.ui.input({
        prompt = "Search: ",
      }, function(input)
        if input then
          Snacks.picker.grep_word({ search = input })
        else
          vim.cmd("echo ''")
        end
      end)
    end

    local run_tmux_command = function()
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

    local function test_file_command()
      if vim.fn.executable("dev") == 1 then
        vim.cmd(":VimuxRunCommand 'dev test '.@%")
      else
        vim.cmd(":TestFile")
      end
    end

    local propagate_paste_buffer_to_osx = function()
      local clipboard_content = vim.fn.getreg("*")
      vim.fn.system("pbcopy-remote", clipboard_content)
      vim.api.nvim_echo({ {
        "clipboard sent",
        "Normal",
      } }, false, {})
    end

    local populate_paste_buffer_from_osx = function()
      local remote_content = vim.fn.system("pbpaste-remote")
      vim.fn.setreg("+", remote_content)
      vim.api.nvim_echo({ {
        "clipboard received",
        "Normal",
      } }, false, {})
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
      {
        "<leader>E",
        function()
          Snacks.explorer.reveal()
        end,
        desc = "Find current file in nvim tree",
      },
      {
        "<leader>b",
        function()
          Snacks.picker.git_branches()
        end,
        desc = "Git branches",
      },
      {
        "<leader>fb",
        function()
          Snacks.picker.buffers()
        end,
        desc = "Buffers list",
      },
      {
        "<leader>e",
        function()
          Snacks.explorer()
        end,
        desc = "Toggle nvim tree",
      },
      {
        ",ff",
        function()
          Snacks.picker.grep_word()
        end,
        desc = "grep word",
      },
      {
        "<leader>ff",
        function()
          Snacks.picker()
        end,
        desc = "Snacks picker",
      },
      {
        "<leader>fh",
        function()
          Snacks.picker.help()
        end,
        desc = "Nvim help",
      },
      {
        "<leader>fs",
        function()
          Snacks.picker.grep()
        end,
        desc = "Grep",
      },
      {
        "q:",
        function()
          Snacks.picker.command_history()
        end,
        desc = "Command history window",
        mode = "n",
      },
      {
        '"',
        function()
          Snacks.picker.registers()
        end,
        desc = "Show registers",
      },
      {
        "<C-p>",
        function()
          Snacks.picker.files({ hidden = true })
        end,
        desc = "Find files",
      },
      {
        "<C-t>",
        function()
          Snacks.picker.smart()
        end,
        desc = "Switch between windows",
      },
      {
        "<C-b>",
        function()
          Snacks.picker.buffers()
        end,
        desc = "Find buffers",
      },
      {
        "<leader>gs",
        function()
          Snacks.picker.git_status()
        end,
        desc = "Git status",
      },
      {
        "<leader>lg",
        function()
          Snacks.lazygit()
        end,
        desc = "lazygit",
      },
      {
        "<leader>sr",
        function()
          local grug = require("grug-far")
          local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
          grug.open({
            transient = true,
            prefills = {
              filesFilter = ext and ext ~= "" and "*." .. ext or nil,
            },
          })
        end,
        mode = { "n", "v" },
        desc = "Search and Replace",
      },
      {
        "s",
        function()
          flash.jump()
        end,
        mode = { "n", "x", "o" },
        desc = "Flash",
      },
      {
        "S",
        function()
          flash.treesitter()
        end,
        mode = { "n", "x", "o" },
        desc = "Flash Treesitter",
      },
      {
        "r",
        function()
          flash.remote()
        end,
        mode = "o",
        desc = "Remote Flash",
      },
      {
        "R",
        function()
          flash.treesitter_search()
        end,
        mode = { "o", "x" },
        desc = "Treesitter Search",
      },
      {
        "<c-s>",
        function()
          flash.toggle()
        end,
        mode = { "c" },
        desc = "Toggle Flash Search",
      },
      {
        "<leader>fr",
        toggle_yazi,
        desc = "yazi",
      },
      { "<leader>O",  ":! open %:h<cr>",                        desc = "Open file in Finder (Mac)" },
      { "<leader>T",  test_file_command,                        desc = "Test current file" },
      { "<leader>V",  "ggVG<cr>",                               desc = "Visually select current buffer" },
      { "<leader>Y",  ":%y+<cr>",                               desc = "Yank current file" },
      { "<leader>Lr", ":LspRestart<cr>",                        desc = "Restart LSP" },
      { "<leader>ft", ":ToggleTerm<cr>",                        desc = "terminal" },
      { "<leader>gB", ":GitLink! blame<cr>",                    desc = "Open git blame link in browser" },
      { "<leader>gb", ":GitLink blame<cr>",                     desc = "Copy git blame link to clipboard" },
      { "<leader>gL", ":GitLink!<cr>",                          desc = "Open git permlink in browser" },
      { "<leader>gl", ":GitLink<cr>",                           desc = "Copy git permlink to clipboard" },
      { "<leader>q",  ":q<cr>",                                 desc = "Close current buffer" },
      { "<leader>t",  ":TestNearest<cr>",                       desc = "Test nearest" },
      { "<leader>v",  ":e ~/.config/nvim/init.lua<cr>",         desc = "Edit init.lua" },
      { "<leader>na", ":Noice<cr>",                             desc = "All notifications" },
      { "<leader>ne", ":Noice errors<cr>",                      desc = "Error notifications" },
      { "<leader>nl", ":Noice last<cr>",                        desc = "Last notification" },
      { "<leader>np", ":Noice pick<cr>",                        desc = "Pick notification" },
      { "gr",         ":Lspsaga finder<cr>",                    desc = "Find references" },
      { "gR",         ":References<cr>",                        desc = "Show references" },
      { "gd",         ":Lspsaga goto_definition<cr>",           desc = "Go to definition" },
      { "gD",         ":Lspsaga peek_definition<cr>",           desc = "Peek definition" },
      { "<leader>ca", ":Lspsaga code_action<cr>",               desc = "Code actions" },
      { "<leader>rn", ":Lspsaga rename<cr>",                    desc = "Rename symbol" },
      { "[d",         ":Lspsaga diagnostic_jump_prev<cr>",      desc = "Previous diagnostic" },
      { "]d",         ":Lspsaga diagnostic_jump_next<cr>",      desc = "Next diagnostic" },
      { "K",          ":Lspsaga hover_doc<cr>",                 desc = "Show hover documentation" },
      { "<",          ":BufferLineMovePrev<cr>",                desc = "Focus far left pane" },
      { ">",          ":BufferLineMoveNext<cr>",                desc = "Focus far right pane" },
      { "<BS>",       ":noh<cr>:echo ''<cr>:Noice dismiss<cr>", desc = "Clear search and messages" },
      { "<C-f>",      search_prompt,                            desc = "Search" },
      { "<S-h>",      ":BufferLineCyclePrev<cr>",               desc = "Previous buffer" },
      { "<S-l>",      ":BufferLineCycleNext<cr>",               desc = "Next buffer" },
      {
        "<S-x>",
        function()
          Snacks.bufdelete()
        end,
        desc = "Delete buffer",
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
          windows.smart_swap("h")
        end,
        desc = "Swap window left",
      },
      {
        "<C-w>J",
        function()
          windows.smart_swap("j")
        end,
        desc = "Swap window down",
      },
      {
        "<C-w>K",
        function()
          windows.smart_swap("k")
        end,
        desc = "Swap window up",
      },
      {
        "<C-w>L",
        function()
          windows.smart_swap("l")
        end,
        desc = "Swap window right",
      },
    })
    local ssh_client = os.getenv("SSH_CLIENT")

    if ssh_client then
      whichkey.add({
        {
          "<leader>p",
          populate_paste_buffer_from_osx,
          desc = "Paste from host to client",
        },
        {
          "<leader>y",
          propagate_paste_buffer_to_osx,
          desc = "Yank from client to host",
        },
      })
    end

    vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

    return {
      preset = "helix",
    }
  end,
}
