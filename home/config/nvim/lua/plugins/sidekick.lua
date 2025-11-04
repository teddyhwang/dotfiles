return {
  {
    "zbirenbaum/copilot.lua",
    opts = {
      copilot_node_command = vim.fn.executable("/opt/homebrew/bin/node") == 1 and "/opt/homebrew/bin/node"
        or "node",
    },
  },
}
