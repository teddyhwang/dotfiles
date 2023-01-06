local function tmuxSplitCommand()
  local command = vim.fn.input("Command: ")
  if command ~= "" then
    vim.cmd(string.format(":VimuxRunCommand '%s'", command))
  end
end

vim.keymap.set("n", "<leader>!", tmuxSplitCommand, { noremap = true })
