local has_shadowenv = vim.fn.executable("shadowenv") == 1

return {
  -- Improved Ruby indentation
  {
    "vim-ruby/vim-ruby",
    ft = "ruby",
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lua_ls = {},
        html = {
          filetypes = { "html", "eruby" },
        },
        ts_ls = {
          enabled = true,
          filetypes = {
            "javascript",
            "javascriptreact",
            "javascript.jsx",
            "typescript",
            "typescriptreact",
            "typescript.tsx",
          },
        },
        cssls = {},
        graphql = {},
        ruby_lsp = {
          enabled = not has_shadowenv,
          init_options = {
            formatter = "rubocop",
          },
        },
        rubocop = {
          enabled = false,
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        ["*"] = { "codespell" },
        ["_"] = { "trim_whitespace" },
        ruby = { "rubocop" },
      },
      formatters = {
        rubocop = has_shadowenv and {
          command = "shadowenv",
          args = {
            "exec",
            "--",
            "bundle",
            "exec",
            "rubocop",
            "--autocorrect",
            "--format",
            "quiet",
            "--stderr",
            "--stdin",
            "$FILENAME",
          },
          cwd = require("conform.util").root_file({ "Gemfile", ".rubocop.yml" }),
          require_cwd = true,
        } or nil,
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        ruby = { "rubocop" },
      },
      linters = {
        ["markdownlint-cli2"] = {
          args = { "--config", vim.fn.expand("~/.markdownlint-cli2.yaml") },
        },
        rubocop = has_shadowenv and {
          cmd = "shadowenv",
          args = {
            "exec",
            "--",
            "bundle",
            "exec",
            "rubocop",
            "--format",
            "json",
            "--stdin",
            function()
              return vim.api.nvim_buf_get_name(0)
            end,
          },
        } or nil,
      },
    },
  },
}
