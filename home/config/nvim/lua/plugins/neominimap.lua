return {
  {
    "Isrothy/neominimap.nvim",
    version = "v3.x.x",
    lazy = false,
    init = function()
      vim.g.neominimap = {
        auto_enable = true,
        winopt = function(opt, _)
          opt.winblend = 40 -- 0-100, higher = more transparent
        end,
      }
    end,
  },
}
