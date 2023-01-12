local opts = { silent = true }

vim.g.mapleader = "\\"

vim.keymap.set("n", "<BS>", ":noh<cr>", opts)

vim.keymap.set("n", "<leader>+", "<C-a>") -- increment numbers
vim.keymap.set("n", "<leader>-", "<C-x>") -- decrement numbers

vim.keymap.set("n", ">", "<C-w>20l", opts)
vim.keymap.set("n", "<", "<C-w>20h", opts)

vim.keymap.set("n", "<leader>to", ":tabnew<CR>") -- open new tab
vim.keymap.set("n", "<leader>tx", ":tabclose<CR>") -- close current tab
vim.keymap.set("n", "<leader>tn", ":tabn<CR>") --  go to next tab
vim.keymap.set("n", "<leader>tp", ":tabp<CR>") --  go to previous tab

vim.keymap.set("n", "<leader>q", ":q<CR>") -- close current buffer

vim.keymap.set("n", "<leader>r", ":source $MYVIMRC<CR>")
vim.keymap.set("n", "<leader>v", ":e ~/.config/nvim/init.lua")
vim.keymap.set("n", "<leader>V", "ggVG")
vim.keymap.set("n", "<leader>y", ":%y+")
vim.keymap.set("n", "<leader>o", ":! open %:h")
vim.keymap.set("n", "<leader>!", ":call TmuxSplitCommand()")
