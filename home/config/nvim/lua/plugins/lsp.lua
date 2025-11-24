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
      },
    },
  },
}
