return {
  {
    "lmilojevicc/herdr-splits.nvim",
    cond = vim.env.HERDR_ENV == "1",
    event = "VeryLazy",
    build = ":lua require('herdr-splits').sync_herdr()",
    config = function()
      require("herdr-splits").setup({
        auto_sync_herdr = true,
        at_edge = "stop",
        nav_at_edge = "stop",
        resize_keys = {
          left = "<C-M-h>",
          down = "<C-M-j>",
          up = "<C-M-k>",
          right = "<C-M-l>",
        },
      })
    end,
    keys = {
      { "<C-h>", function() require("herdr-splits").move_cursor_left() end, desc = "Navigate left" },
      { "<C-j>", function() require("herdr-splits").move_cursor_down() end, desc = "Navigate down" },
      { "<C-k>", function() require("herdr-splits").move_cursor_up() end, desc = "Navigate up" },
      { "<C-l>", function() require("herdr-splits").move_cursor_right() end, desc = "Navigate right" },
      { "<C-M-h>", function() require("herdr-splits").resize_left() end, desc = "Resize left" },
      { "<C-M-j>", function() require("herdr-splits").resize_down() end, desc = "Resize down" },
      { "<C-M-k>", function() require("herdr-splits").resize_up() end, desc = "Resize up" },
      { "<C-M-l>", function() require("herdr-splits").resize_right() end, desc = "Resize right" },
    },
  },
}
