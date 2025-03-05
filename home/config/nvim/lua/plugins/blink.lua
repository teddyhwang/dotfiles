return {
  "saghen/blink.cmp",
  dependencies = {
    {
      "L3MON4D3/LuaSnip",
      build = "make install_jsregexp",
      dependencies = { "rafamadriz/friendly-snippets" },
    },
    "giuxtaposition/blink-cmp-copilot",
    {
      "zbirenbaum/copilot.lua",
      cmd = "Copilot",
      event = "InsertEnter",
      opts = {
        suggestion = { enabled = false, auto_trigger = true },
        panel = { enabled = false },
        copilot_node_command = vim.fn.executable("/opt/homebrew/bin/node") == 1 and "/opt/homebrew/bin/node" or "node",
      },
    },
  },
  version = "*",
  build = "cargo build --release",
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
    sources = {
      default = { "copilot", "lsp", "path", "snippets", "buffer" },
      providers = {
        copilot = {
          name = "copilot",
          module = "blink-cmp-copilot",
          score_offset = 100,
          async = true,
        },
      },
    },
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
  opts_extend = { "sources.default" },
}
