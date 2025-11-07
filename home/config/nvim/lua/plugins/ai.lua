return {
  {
    "zbirenbaum/copilot.lua",
    opts = {
      copilot_node_command = vim.fn.executable("/opt/homebrew/bin/node") == 1 and "/opt/homebrew/bin/node" or "node",
    },
  },
  {
    "folke/sidekick.nvim",
    opts = {
      cli = {
        mux = {
          backend = "tmux",
          enabled = true,
          create = "split",
          split = {
            vertical = true,
            size = 0.3,
          },
        },
      },
    },
  },
}
