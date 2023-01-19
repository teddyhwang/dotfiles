local setup, nvimtree = pcall(require, "nvim-tree")
if not setup then
  return
end

-- don't hijack netrw so can coexist with :Explorer
-- vim.g.loaded_netrw = 1
-- vim.g.loaded_netrwPlugin = 1

nvimtree.setup({
  hijack_directories = {
    enable = false,
    auto_open = false,
  },
  hijack_netrw = false,
  renderer = {
    icons = {
      glyphs = {
        folder = {
          arrow_closed = "",
          arrow_open = "",
        },
      },
    },
  },
  -- disable window_picker for explorer to work well with window splits
  actions = {
    open_file = {
      window_picker = {
        enable = false,
      },
    },
  },
})

vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>")
vim.keymap.set("n", "<leader>E", ":NvimTreeFindFile<CR>")
