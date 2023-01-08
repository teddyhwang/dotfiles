local mason_status, mason = pcall(require, "mason")
if not mason_status then
  return
end

local mason_lspconfig_status, mason_lspconfig = pcall(require, "mason-lspconfig")
if not mason_lspconfig_status then
  return
end

local mason_null_ls_status, mason_null_ls = pcall(require, "mason-null-ls")
if not mason_null_ls_status then
  return
end

mason.setup()

mason_lspconfig.setup({
  ensure_installed = {
    "bash-language-server",
    "cssls",
    "emmet_ls",
    "html",
    "ruby_ls",
    "solargraph",
    "sorbet",
    "sumneko_lua",
    "tailwindcss",
    "tsserver",
  },
  automatic_installation = true,
})

mason_null_ls.setup({
  ensure_installed = {
    "eslint_d", -- ts/js linter
    "prettier", -- ts/js formatter
    "stylua", -- lua formatter
  },
  automatic_installation = true,
})
