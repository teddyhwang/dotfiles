local setup, null_ls = pcall(require, "null-ls")
if not setup then
  return
end

local formatting = null_ls.builtins.formatting
local diagnostics = null_ls.builtins.diagnostics

local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

null_ls.setup({
  sources = {
    formatting.prettierd,
    formatting.stylua,
    formatting.rubocop.with({
      condition = function()
        return vim.fn.executable("rubocop") == 1
      end,
    }),
    diagnostics.rubocop.with({
      extra_args = { "--server" },
      condition = function()
        return vim.fn.executable("rubocop") == 1
      end,
    }),
    diagnostics.eslint_d.with({
      condition = function(utils)
        return utils.root_has_file(".eslintrc.js") -- change file extension if you use something else
      end,
    }),
  },
  -- configure format on save
  on_attach = function(current_client, bufnr)
    if current_client.supports_method("textDocument/formatting") then
      vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = augroup,
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format({
            filter = function(client)
              return client.name == "null-ls"
            end,
            bufnr = bufnr,
            timeout_ms = 5000,
          })
        end,
      })
    end
  end,
})
