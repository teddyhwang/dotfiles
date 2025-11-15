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
      nes = {
        enabled = false,
      },
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
    config = function(_, opts)
      require("sidekick").setup(opts)

      -- Hide inline distractions when Sidekick NES is active
      local inlay_hints_enabled = {}
      local git_blame_enabled = {}
      local diagnostics_enabled = {}

      vim.api.nvim_create_autocmd("User", {
        pattern = "SidekickNesShow",
        callback = function(ev)
          local buf = ev.buf
          -- Store and disable inlay hints
          inlay_hints_enabled[buf] = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
          if inlay_hints_enabled[buf] then
            vim.lsp.inlay_hint.enable(false, { bufnr = buf })
          end
          -- Store and disable git blame
          if vim.g.gitblame_enabled ~= 0 then
            git_blame_enabled[buf] = true
            vim.cmd("GitBlameDisable")
          end
          -- Store and disable inline diagnostics
          diagnostics_enabled[buf] = vim.diagnostic.is_enabled({ bufnr = buf })
          if diagnostics_enabled[buf] then
            vim.diagnostic.enable(false, { bufnr = buf })
          end
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        pattern = "SidekickNesHide",
        callback = function(ev)
          local buf = ev.buf
          -- Restore inlay hints
          if inlay_hints_enabled[buf] then
            vim.lsp.inlay_hint.enable(true, { bufnr = buf })
            inlay_hints_enabled[buf] = nil
          end
          -- Restore git blame
          if git_blame_enabled[buf] then
            vim.cmd("GitBlameEnable")
            git_blame_enabled[buf] = nil
          end
          -- Restore diagnostics
          if diagnostics_enabled[buf] then
            vim.diagnostic.enable(true, { bufnr = buf })
            diagnostics_enabled[buf] = nil
          end
        end,
      })
    end,
  },
}
