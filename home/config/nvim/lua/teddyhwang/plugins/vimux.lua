vim.g["test#strategy"] = "vimux"

local function tmuxSplitCommand()
  local command = vim.fn.input("Command: ")
  if command ~= "" then
    vim.cmd(string.format(":VimuxRunCommand '%s'", command))
  end
end

vim.keymap.set("n", "<leader>!", tmuxSplitCommand, { noremap = true })
vim.keymap.set("n", "<leader>t", ":TestNearest", { noremap = true })
vim.keymap.set("n", "<leader>T", ":VimuxRunCommand 'dev test '.@%", { noremap = true })
vim.keymap.set("n", "<leader>l", ":VimuxRunLastCommand", { noremap = true })
