return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.scroll = { enabled = false }
      opts.indent = { enabled = true }
      opts.explorer = { enabled = true }
      opts.bigfile = { enabled = true }

      -- Add custom toggle for autoformat
      opts.toggle = vim.tbl_deep_extend("force", opts.toggle or {}, {
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
      })

      -- De-emphasize .rbi files in picker results
      opts.picker = vim.tbl_deep_extend("force", opts.picker or {}, {
        transform = function(item)
          if item.file and item.file:match("%.rbi$") then
            item.score_add = -50
          end
          return item
        end,
      })

      -- Use fff.nvim for the dashboard "Find File" action instead of the snacks
      -- picker. Patch the action in place so LazyVim's default icons/keys stay
      -- intact (avoids hardcoding nerd-font glyphs).
      local keys = vim.tbl_get(opts, "dashboard", "preset", "keys")
      if keys then
        for _, k in ipairs(keys) do
          if k.key == "f" then
            k.action = function()
              require("fff").find_files()
            end
          end
        end
      end
    end,
  },
}
