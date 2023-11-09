local setup, null_ls = pcall(require, "null-ls")
if not setup then
  return
end

local lsp_format_status, lsp_format = pcall(require, "lsp-format")
if not lsp_format_status then
  return
end

lsp_format.setup({})

local formatting = null_ls.builtins.formatting
local diagnostics = null_ls.builtins.diagnostics

null_ls.setup({
  sources = {
    formatting.eslint_d,
    formatting.fixjson,
    formatting.prettierd.with({
      filetypes = {
        "css",
        "scss",
        "less",
        "html",
        "json",
        "yaml",
        "markdown",
        "graphql",
      },
    }),
    formatting.stylua,
    formatting.stylelint,
    formatting.rubocop.with({
      extra_args = { "--server" },
      ignore_stderr = true,
      condition = function()
        return vim.fn.executable("rubocop") == 1
      end,
    }),
    formatting.yamlfmt,
    diagnostics.stylelint,
    diagnostics.rubocop.with({
      extra_args = { "--server" },
      ignore_stderr = true,
      condition = function()
        return vim.fn.executable("rubocop") == 1
      end,
    }),
    diagnostics.eslint_d,
    diagnostics.yamllint,
  },
  on_attach = lsp_format.on_attach,
})
