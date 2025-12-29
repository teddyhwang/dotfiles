-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- Better increment/decrement
map("n", "<leader>+", "<C-a>", { desc = "Increment number" })
map("n", "<leader>-", "<C-x>", { desc = "Decrement number" })

-- Clear search highlighting
map("n", "<BS>", ":noh<cr>:echo ''<cr>", { desc = "Clear search and messages", silent = true })

-- Buffer navigation - cycle through buffers in tab order
map("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
map("n", "<S-x>", function()
  require("snacks").bufdelete()
end, { desc = "Delete buffer" })

-- Move buffer position in buffer list
map("n", "<", "<cmd>BufferLineMovePrev<cr>", { desc = "Move buffer left" })
map("n", ">", "<cmd>BufferLineMoveNext<cr>", { desc = "Move buffer right" })

-- File operations
map("n", "<leader>e", function()
  local snacks = require("snacks")
  snacks.explorer()
end, { desc = "Toggle file explorer" })

map("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory" })

map("n", "<leader>oo", "<cmd>Other<cr>", { desc = "Open alternate file" })
map("n", "<leader>os", "<cmd>OtherSplit<cr>", { desc = "Open alternate file in split" })
map("n", "<leader>ov", "<cmd>OtherVSplit<cr>", { desc = "Open alternate file in vsplit" })
map("n", "<leader>ot", "<cmd>OtherTabNew<cr>", { desc = "Open alternate file in new tab" })

map("n", "<leader>fr", function()
  require("util.yazi").open()
end, { desc = "Open yazi file manager" })

map("n", "<leader>fy", function()
  local filepath = vim.fn.expand("%:.")
  if filepath ~= "" then
    vim.fn.setreg("+", filepath)
    vim.notify("Copied: " .. filepath)
  else
    vim.notify("No filepath for current buffer", vim.log.levels.WARN)
  end
end, { desc = "Copy relative file path" })

map("n", "<leader>fY", function()
  local filepath = vim.fn.expand("%:p")
  if filepath ~= "" then
    vim.fn.setreg("+", filepath)
    vim.notify("Copied: " .. filepath)
  else
    vim.notify("No filepath for current buffer", vim.log.levels.WARN)
  end
end, { desc = "Copy absolute file path" })

map("n", "<leader>ft", function()
  require("snacks").terminal.open()
end, { desc = "Toggle terminal" })

-- Find/Search operations using LazyVim's pickers
map("n", "<C-p>", "<cmd>lua require('snacks').picker.files({ hidden = true })<cr>", { desc = "Find files" })
map("n", "<C-b>", "<cmd>lua require('snacks').picker.buffers()<cr>", { desc = "Find buffers" })
map("n", "<C-t>", "<cmd>lua require('snacks').picker.smart()<cr>", { desc = "Smart picker" })
map("n", "<leader>fb", "<cmd>lua require('snacks').picker.buffers()<cr>", { desc = "Buffers list" })
map("n", "<leader>fh", "<cmd>lua require('snacks').picker.help()<cr>", { desc = "Nvim help" })
map("n", "<leader>fg", "<cmd>lua require('snacks').picker.grep()<cr>", { desc = "Grep" })
map("n", ",ff", "<cmd>lua require('snacks').picker.grep_word({ hidden = true })<cr>", { desc = "Grep word" })

-- Search with prompt
map("n", "<C-f>", function()
  vim.ui.input({
    prompt = "Search: ",
  }, function(input)
    if input then
      require("snacks").picker.grep_word({ search = input, hidden = true })
    end
  end)
end, { desc = "Search" })

-- Git operations
map("n", "<leader>gb", "<cmd>lua require('snacks').picker.git_branches()<cr>", { desc = "Git branches" })
map("n", "<leader>gl", "<cmd>lua require('snacks').picker.git_log()<cr>", { desc = "Git logs" })
map("n", "<leader>gd", "<cmd>lua require('snacks').picker.git_diff()<cr>", { desc = "Git diff" })
map("n", "<leader>gs", "<cmd>lua require('snacks').picker.git_status()<cr>", { desc = "Git status" })
map("n", "<leader>lg", "<cmd>lua require('snacks').lazygit()<cr>", { desc = "Lazygit" })

-- GitLinker - Generate GitHub permalinks
map("n", "<leader>gy", "<cmd>GitLink<cr>", { desc = "Copy git permalink" })
map("n", "<leader>gY", "<cmd>GitLink!<cr>", { desc = "Open git permalink in browser" })
map("n", "<leader>gv", "<cmd>GitLink blame<cr>", { desc = "Copy git blame link" })
map("n", "<leader>gV", "<cmd>GitLink! blame<cr>", { desc = "Open git blame link in browser" })

map("n", "<leader>gws", function()
  require("snacks").picker.worktrees()
end, { desc = "Git worktrees" })
map("n", "<leader>gwn", function()
  require("snacks").picker.worktrees_new()
end, { desc = "Create new git worktree" })
map("n", "<leader>gwd", function()
  require("snacks").picker.worktrees_remove()
end, { desc = "Remove git worktree" })

-- Command history and registers
map("n", "q:", "<cmd>lua require('snacks').picker.command_history()<cr>", { desc = "Command history" })
map("n", '"', "<cmd>lua require('snacks').picker.registers()<cr>", { desc = "Show registers" })

-- LSP keymaps (these override LazyVim defaults to match your muscle memory)
map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "gr", "<cmd>lua require('snacks').picker.lsp_references()<cr>", { desc = "Find references" })
map("n", "gI", vim.lsp.buf.implementation, { desc = "Go to implementation" })
map("n", "gy", vim.lsp.buf.type_definition, { desc = "Go to type definition" })
map("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
map("n", "K", vim.lsp.buf.hover, { desc = "Hover" })
map("n", "gK", vim.lsp.buf.signature_help, { desc = "Signature Help" })
map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename" })

-- Diagnostic navigation
map("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })
map("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })

-- Utility
map("n", "<leader>V", "ggVG<cr>", { desc = "Select entire buffer" })
map("n", "<leader>Y", ":%y+<cr>", { desc = "Yank entire buffer" })
map("n", "<leader>q", ":q<cr>", { desc = "Close buffer" })
map("n", "<leader>v", ":e ~/.config/nvim/init.lua<cr>", { desc = "Edit init.lua" })

map("n", "<leader>ym", function()
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.notifier then
    print("Snacks notifier not available")
    return
  end

  local history = snacks.notifier.get_history()

  if #history > 0 then
    -- Get the last notification
    local last = history[#history]
    ---@type string
    local msg
    if type(last.msg) == "table" then
      ---@diagnostic disable-next-line: param-type-mismatch
      msg = table.concat(last.msg, "\n")
    else
      msg = tostring(last.msg)
    end
    vim.fn.setreg("+", msg)
    print("Copied: " .. msg)
  else
    print("No notifications to copy")
  end
end, { desc = "Copy last notification" })

-- Neominimap keymaps
map("n", "<leader>uM", "<cmd>Neominimap Toggle<cr>", { desc = "Toggle global minimap" })

-- Tmux integration
map("n", "<leader>!", function()
  vim.ui.input({
    prompt = "Command: ",
  }, function(input)
    if input then
      vim.cmd(string.format(":VimuxRunCommand '%s'", input))
    end
  end)
end, { desc = "Run command in tmux split" })

map("n", "<leader>T", function()
  if vim.fn.executable("/opt/dev/bin/dev") == 1 then
    vim.cmd(":VimuxRunCommand 'dev test '.@%")
  else
    vim.cmd(":TestFile")
  end
end, { desc = "Test current file" })

map("n", "<leader>t", ":TestNearest<cr>", { desc = "Test nearest" })

-- Terminal mode escape
map("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Database UI
map("n", "<leader>D", "<cmd>DBUIToggle<cr>", { desc = "Toggle Dadbod UI" })

-- Sidekick AI
map("n", "<leader>ac", function()
  require("sidekick.cli").toggle({ name = "claude", focus = true })
end, { desc = "Toggle Claude" })

-- Stewardlens
map("n", "<leader>fs", "<cmd>StewardlensBrowse<cr>", { desc = "Open file in Stewardlens" })
