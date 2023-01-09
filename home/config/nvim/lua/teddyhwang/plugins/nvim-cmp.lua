local cmp_status, cmp = pcall(require, "cmp")
if not cmp_status then
  return
end

local luasnip_status, luasnip = pcall(require, "luasnip")
if not luasnip_status then
  return
end

local lspkind_status, lspkind = pcall(require, "lspkind")
if not lspkind_status then
  return
end

require("luasnip/loaders/from_vscode").lazy_load()

vim.opt.completeopt = "menu,menuone,noselect"

cmp.setup({
  completion = {
    completeopt = "menu,menuone,noinsert",
  },
  window = {
    -- completion = cmp.config.window.bordered(),
    -- documentation = cmp.config.window.bordered(),
  },
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-k>"] = cmp.mapping.select_prev_item(),
    ["<C-j>"] = cmp.mapping.select_next_item(),
    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.abort(),
    ["<esc>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.abort()
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<CR>"] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Replace,
      select = false,
    }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.confirm({ select = true })
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        local copilot_keys = vim.fn["copilot#Accept"]("")
        if copilot_keys ~= "" then
          vim.api.nvim_feedkeys(copilot_keys, "i", true)
        else
          fallback()
        end
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      local copilot_keys = vim.fn["copilot#Accept"]("")
      if copilot_keys ~= "" then
        vim.api.nvim_feedkeys(copilot_keys, "i", true)
      elseif cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp" }, -- lsp
    { name = "luasnip" }, -- snippets
    { name = "buffer" }, -- text within current buffer
    { name = "path" }, -- file system paths
  }),
  -- configure lspkind for vs-code like icons
  formatting = {
    format = lspkind.cmp_format({
      maxwidth = 150,
      ellipsis_char = "...",
    }),
  },
})

local opts = { noremap = true, silent = true }
vim.keymap.set("i", "<C-j>", "<cmd>lua require'luasnip'.jump(1)<CR>", opts)
vim.keymap.set("s", "<C-j>", "<cmd>lua require'luasnip'.jump(1)<CR>", opts)
vim.keymap.set("i", "<C-k>", "<cmd>lua require'luasnip'.jump(-1)<CR>", opts)
vim.keymap.set("s", "<C-k>", "<cmd>lua require'luasnip'.jump(-1)<CR>", opts)
