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
  {
    "andymass/vim-matchup", -- show relative number of closing block
    init = function()
      vim.g["matchup_matchparen_offscreen"] = { method = "popup" }
    end,
  },

  -- Git
  "f-person/git-blame.nvim", -- Inline git blame at end of line
  {
    "linrongbin16/gitlinker.nvim", -- Generate GitHub permalinks
    opts = function()
      local function delta(rev)
        return "https://delta.shopify.io/{_A.ORG}/{_A.REPO}/blob/"
          .. rev
          .. "/{_A.FILE}#L{_A.LSTART}{(_A.LEND > _A.LSTART and ('-L' .. _A.LEND) or '')}"
      end
      return {
        router = {
          browse = { ["^delta%.shopify%.io"] = delta("{_A.REV}") },
          default_branch = { ["^delta%.shopify%.io"] = delta("{_A.DEFAULT_BRANCH}") },
          current_branch = { ["^delta%.shopify%.io"] = delta("{_A.CURRENT_BRANCH}") },
        },
      }
    end,
  },
  { "Juksuu/worktrees.nvim", config = true }, -- Git worktree management

  -- Editing
  "mg979/vim-visual-multi", -- Multiple cursors with <C-n>
  "sitiom/nvim-numbertoggle", -- Auto-toggle relative/absolute line numbers
}
