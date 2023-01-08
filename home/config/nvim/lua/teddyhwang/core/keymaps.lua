vim.g.mapleader = "\\"

vim.keymap.set("n", "<BS>", ":noh<cr>", { silent = true })

vim.keymap.set("n", "<leader>+", "<C-a>") -- increment numbers
vim.keymap.set("n", "<leader>-", "<C-x>") -- decrement numbers

vim.keymap.set("n", "<leader>r", ":source ~/.config/nvim/init.lua<CR>")

vim.keymap.set("n", "<leader>to", ":tabnew<CR>") -- open new tab
vim.keymap.set("n", "<leader>tx", ":tabclose<CR>") -- close current tab
vim.keymap.set("n", "<leader>tn", ":tabn<CR>") --  go to next tab
vim.keymap.set("n", "<leader>tp", ":tabp<CR>") --  go to previous tab
