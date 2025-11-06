return {
  {
    "folke/snacks.nvim",
    opts = {
      scroll = { enabled = false },
      indent = { enabled = true },
      explorer = { enabled = true },
      bigfile = {
        enabled = true,
        setup = function(ctx)
          -- Exclude graphql files from bigfile detection
          if vim.bo[ctx.buf].filetype == "graphql" then
            return false
          end
        end,
      },
      -- Add custom toggle for autoformat
      toggle = {
        format = {
          name = "Auto Format",
          get = function()
            return not (vim.g.disable_autoformat or vim.b.disable_autoformat)
          end,
          set = function(state)
            if state then
              vim.b.disable_autoformat = false
              vim.g.disable_autoformat = false
            else
              vim.b.disable_autoformat = true
            end
          end,
        },
      },
      -- De-emphasize .rbi files in picker results
      picker = {
        transform = function(item)
          if item.file and item.file:match("%.rbi$") then
            item.score_add = -50
          end
          return item
        end,
      },
    },
  },
}
