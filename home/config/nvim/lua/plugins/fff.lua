return {
  {
    "dmtrKovalenko/fff.nvim",
    build = function(plugin)
      vim.opt.runtimepath:append(plugin.dir)
      require("fff.download").download_or_build_binary()
    end,
    lazy = false,
    opts = {
      layout = {
        prompt_position = "top",
      },
      keymaps = {
        close = { "<Esc>", "<C-c>" },
        move_up = { "<Up>", "<C-k>", "<C-p>" },
        move_down = { "<Down>", "<C-j>", "<C-n>" },
      },
    },
  },
}
