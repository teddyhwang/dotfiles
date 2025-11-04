return {
  -- Disable nvim-cmp
  { "hrsh7th/nvim-cmp", enabled = false },

  -- Enable blink.cmp
  {
    "saghen/blink.cmp",
    version = "*",
    dependencies = {
      "kristijanhusak/vim-dadbod-completion",
    },
    opts = {
      keymap = {
        preset = "super-tab",
        ["<C-k>"] = { "select_prev", "fallback" },
        ["<C-j>"] = { "select_next", "fallback" },
      },
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = "normal",
      },
      completion = {
        menu = {
          border = "rounded",
          draw = {
            columns = {
              { "label", "label_description", gap = 1 },
              { "kind_icon", "kind" },
            },
          },
        },
        list = {
          selection = {
            auto_insert = false,
          },
        },
        documentation = {
          window = {
            border = "rounded",
          },
          auto_show = true,
          auto_show_delay_ms = 200,
        },
        ghost_text = {
          enabled = true,
          show_without_selection = true,
        },
      },
      cmdline = {
        enabled = true,
        completion = {
          menu = {
            auto_show = true,
          },
        },
        keymap = {
          preset = "none",
          ["<Tab>"] = { "show", "select_and_accept", "fallback" },
          ["<S-Tab>"] = { "show", "select_prev", "fallback" },
          ["<C-j>"] = { "show", "select_next", "fallback" },
          ["<C-k>"] = { "show", "select_prev", "fallback" },
          ["<C-y>"] = { "accept", "fallback" },
          ["<C-e>"] = { "cancel", "fallback" },
          ["<C-space>"] = { "show", "fallback" },
        },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        per_filetype = {
          sql = { "dadbod", "buffer" },
          mysql = { "dadbod", "buffer" },
          plsql = { "dadbod", "buffer" },
        },
        providers = {
          dadbod = {
            name = "Dadbod",
            module = "vim_dadbod_completion.blink",
          },
        },
      },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
    opts_extend = { "sources.default" },
  },
}
