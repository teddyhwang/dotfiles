return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-path",
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "onsails/lspkind.nvim",
    "zbirenbaum/copilot-cmp",
    {
      "L3MON4D3/LuaSnip",
      build = "make install_jsregexp",
      dependencies = { "rafamadriz/friendly-snippets" },
    },
  },
  config = function()
    local cmp = require("cmp")
    local luasnip = require("luasnip")
    local lspkind = require("lspkind")
    local copilot_cmp_comparators = require("copilot_cmp.comparators")
    local dev_icons = require("nvim-web-devicons")

    require("luasnip/loaders/from_vscode").lazy_load()

    luasnip.filetype_extend("javascript", { "html" })
    luasnip.filetype_extend("javascriptreact", { "html" })
    luasnip.filetype_extend("typescriptreact", { "html" })

    local has_words_before = function()
      if vim.api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt" then
        return false
      end
      local line, col = unpack(vim.api.nvim_win_get_cursor(0))
      return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
    end

    cmp.setup({
      completion = {
        completeopt = "menu,menuone,noinsert",
      },
      performance = {
        debounce = 0,
      },
      experimental = {
        ghost_text = true,
      },
      window = {
        completion = cmp.config.window.bordered({
          winhighlight = "Normal:Pmenu,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None",
        }),
        documentation = cmp.config.window.bordered({
          winhighlight = "Normal:Pmenu,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None",
        }),
      },
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<C-k>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
        ["<C-j>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<CR>"] = cmp.mapping(
          vim.schedule_wrap(function(fallback)
            local entry = cmp.get_selected_entry()
            if entry and entry.source.name == "copilot" then
              fallback()
            elseif cmp.visible() and has_words_before() then
              cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
            else
              fallback()
            end
          end),
          { "i", "s" }
        ),
        ["<Tab>"] = cmp.mapping(
          vim.schedule_wrap(function(fallback)
            if cmp.visible() and has_words_before() then
              cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end),
          { "i", "s" }
        ),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      }),
      sorting = {
        priority_weight = 2,
        comparators = {
          copilot_cmp_comparators.prioritize,
          copilot_cmp_comparators.score,
          cmp.config.compare.offset,
          cmp.config.compare.exact,
          cmp.config.compare.score,
          cmp.config.compare.recently_used,
          cmp.config.compare.locality,
          cmp.config.compare.kind,
          cmp.config.compare.sort_text,
          cmp.config.compare.length,
          cmp.config.compare.order,
        },
      },
      sources = cmp.config.sources({
        { name = "copilot" },
        { name = "nvim_lsp" },
        { name = "buffer" },
        { name = "path" },
        { name = "luasnip" },
      }),
      formatting = {
        format = function(entry, vim_item)
          if vim.tbl_contains({ "path" }, entry.source.name) then
            local icon, hl_group = dev_icons.get_icon(entry:get_completion_item().label)
            if icon then
              vim_item.kind = icon
              vim_item.kind_hl_group = hl_group
              return vim_item
            end
          end
          return lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 150,
            ellipsis_char = "...",
            symbol_map = { Copilot = "" },
            before = function(before_entry, before_vim_item)
              local kind_hl_group = "CmpItemKind" .. before_vim_item.kind
              before_vim_item.kind_hl_group = kind_hl_group
              before_vim_item.dup = ({
                buffer = 1,
                path = 1,
                nvim_lsp = 0,
              })[before_entry.source.name] or 0

              local strings = vim.split(vim_item.abbr, " ", { trimempty = true })
              if strings[1] then
                vim_item.abbr_hl_group = kind_hl_group
              end

              return vim_item
            end,
          })(entry, vim_item)
        end,
      },
    })

    cmp.setup.filetype({ "sql", "mysql" }, {
      sources = {
        { name = "vim-dadbod-completion" },
        { name = "buffer" },
      },
    })
  end,
}
