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
    formatting.prettierd.with({
      filetypes = {
        "css",
        "scss",
        "less",
        "html",
        "markdown",
        "graphql",
      },
    }),
    formatting.stylua,
    formatting.stylelint,
    diagnostics.stylelint,
    diagnostics.yamllint,
  },
  on_attach = lsp_format.on_attach,
})
