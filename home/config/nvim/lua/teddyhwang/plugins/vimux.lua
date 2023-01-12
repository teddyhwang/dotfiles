vim.g["test#strategy"] = "vimux"

local function tmuxSplitCommand()
  local command = vim.fn.input("Command: ")
  if command ~= "" then
    vim.cmd(string.format(":VimuxRunCommand '%s'", command))
  end
end

vim.keymap.set("n", "<leader>!", tmuxSplitCommand, { noremap = true })
vim.keymap.set("n", "<leader>t", ":TestNearest<CR>", { noremap = true })
vim.keymap.set("n", "<leader>T", ":VimuxRunCommand 'dev test '.@%<CR>", { noremap = true })
vim.keymap.set("n", "<leader>l", ":VimuxRunLastCommand<CR>", { noremap = true })
