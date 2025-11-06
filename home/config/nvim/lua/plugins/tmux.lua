return {
  -- Seamless navigation between tmux panes and vim splits
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate left" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate down" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate up" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right" },
    },
  },

  -- Send commands to tmux from vim
  {
    "preservim/vimux",
    init = function()
      vim.g["test#strategy"] = "vimux"
    end,
  },

  -- Test runner that integrates with vimux
  "vim-test/vim-test",

  -- Tmux syntax highlighting
  "whatyouhide/vim-tmux-syntax",
}
