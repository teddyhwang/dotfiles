return {
  -- Window/Tab Management
  "AndrewRadev/undoquit.vim", -- Restore closed windows with <C-w>u
  "dhruvasagar/vim-zoom", -- Toggle window zoom with <C-w>m
  {
    "simeji/winresizer",
    init = function()
      vim.g.winresizer_horiz_resize = 1
      vim.g.winresizer_vert_resize = 3
    end,
  },
  "vim-scripts/Tabmerge", -- Merge tabs with :Tabmerge

  -- Git
  "f-person/git-blame.nvim", -- Inline git blame at end of line
  { "linrongbin16/gitlinker.nvim", config = true }, -- Generate GitHub permalinks

  -- Editing
  "mg979/vim-visual-multi", -- Multiple cursors with <C-n>
  "sitiom/nvim-numbertoggle", -- Auto-toggle relative/absolute line numbers
}
