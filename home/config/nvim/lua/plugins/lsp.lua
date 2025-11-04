return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- LSP Server Settings
      servers = {
        html = {
          filetypes = { "html", "eruby" },
        },
        ts_ls = {},
        cssls = {},
        tailwindcss = {},
        eslint = {},
        graphql = {},
        jsonls = {},
        lua_ls = {
          settings = {
            Lua = {
              workspace = {
                checkThirdParty = false,
              },
              codeLens = {
                enable = true,
              },
              completion = {
                callSnippet = "Replace",
              },
              doc = {
                privateName = { "^_" },
              },
              hint = {
                enable = true,
                setType = false,
                paramType = true,
                paramName = "Disable",
                semicolon = "Disable",
                arrayIndex = "Disable",
              },
            },
          },
        },
        ruby_lsp = {
          init_options = {
            formatter = "rubocop",
          },
        },
        rubocop = {
          -- Disable rubocop LSP since ruby_lsp handles it
          enabled = false,
        },
        yamlls = {},
      },
      -- Additional setup for servers
      setup = {},
    },
  },

  -- Configure conform.nvim for formatting
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        sh = { "shfmt" },
        css = { "prettierd", "prettier", stop_after_first = true },
        graphql = { "prettierd", "prettier", stop_after_first = true },
        html = { "prettierd", "prettier", stop_after_first = true },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        json = { "prettierd", "prettier", stop_after_first = true },
        less = { "prettierd", "prettier", stop_after_first = true },
        markdown = { "prettierd", "prettier", stop_after_first = true },
        scss = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        ["*"] = { "codespell" },
        ["_"] = { "trim_whitespace" },
      },
    },
  },

  -- Configure nvim-lint
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        yaml = { "yamllint" },
      },
    },
  },
}
