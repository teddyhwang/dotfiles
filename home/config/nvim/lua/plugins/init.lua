return {
  "tpope/vim-sensible",
  {
    "akinsho/bufferline.nvim",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("restart").bufferline()
    end,
  },
  { "j-hui/fidget.nvim",         config = true },
  { "NvChad/nvim-colorizer.lua", config = true },
  "sitiom/nvim-numbertoggle",
  "kristijanhusak/vim-carbon-now-sh",
  {
    "machakann/vim-highlightedyank",
    init = function()
      vim.g["highlightedyank_highlight_duration"] = 100
    end,
  },
  {
    "andymass/vim-matchup",
    init = function()
      vim.g["matchup_matchparen_offscreen"] = { method = "popup" }
    end,
  },
  "christoomey/vim-tmux-navigator",
  {
    "preservim/vimux",
    config = function()
      vim.g["test#strategy"] = "vimux"
    end,
  },
  "vim-test/vim-test",
  {
    "voldikss/vim-floaterm",
    init = function()
      vim.g["floaterm_autoclose"] = 1
      vim.g["floaterm_gitcommit"] = "floaterm"
      vim.g["floaterm_height"] = 0.8
      vim.g["floaterm_keymap_new"] = "<F4>"
      vim.g["floaterm_keymap_next"] = "<F2>"
      vim.g["floaterm_keymap_prev"] = "<F3>"
      vim.g["floaterm_keymap_toggle"] = "<F1>"
      vim.g["floaterm_opener"] = "vsplit"
      vim.g["floaterm_width"] = 0.8
    end,
  },
  "AndrewRadev/undoquit.vim",
  "dhruvasagar/vim-zoom",
  {
    "simeji/winresizer",
    init = function()
      vim.g["winresizer_horiz_resize"] = 1
      vim.g["winresizer_vert_resize"] = 3
    end,
  },
  "tpope/vim-obsession",
  "vim-scripts/Tabmerge",
  {
    "airblade/vim-rooter",
    init = function()
      vim.g["rooter_patterns"] = { ".git", ".git/", "Gemfile", "package.json", "CHANGELOG.md" }
    end,
  },
  {
    "stevearc/oil.nvim",
    opts = {
      keymaps = {
        ["<BS>"] = "actions.parent",
        ["<C-p>"] = false,
        ["<C-h>"] = "actions.toggle_hidden",
      },
      skip_confirm_for_simple_edits = true,
      view_options = {
        show_hidden = true,
      },
    },
  },
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      bigfile = { enabled = false },
      dashboard = { enabled = true },
      dim = { enabled = true },
      explorer = { enabled = true },
      image = { force = true },
      indent = { enabled = true },
      input = { enabled = true },
      lazygit = {
        theme = {
          activeBorderColor = { fg = "Title", bold = true },
        },
      },
      picker = { enabled = true },
      notifier = { enabled = true },
      quickfile = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = true },
      styles = { enabled = true },
      toggle = { enabled = true },
      words = { enabled = true },
      zen = { enabled = true },
    },
    init = function()
      vim.g.snacks_animate = false
    end,
  },
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = false,
        lsp_doc_border = false,
      },
    },
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
  },
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      suggestion = { enabled = false, auto_trigger = true },
      panel = { enabled = false },
      copilot_node_command = vim.fn.executable("/opt/homebrew/bin/node") == 1 and "/opt/homebrew/bin/node" or "node",
    },
    dependencies = {
      {
        "zbirenbaum/copilot-cmp",
        config = function()
          require("copilot_cmp").setup({
            formatters = {
              insert_text = require("copilot_cmp.format").format_existing_text,
            },
          })
        end,
      },
    },
  },
  {
    "glepnir/lspsaga.nvim",
    event = "BufRead",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
      "nvim-treesitter/nvim-treesitter",
      "RRethy/nvim-base16",
    },
    config = function()
      local base16 = require("base16-colorscheme")
      local lspsaga = require("lspsaga")
      local colors = base16.colors or base16.colorschemes[vim.env.BASE16_THEME or "seti"]
      lspsaga.setup({
        symbol_in_winbar = {
          enable = false,
          delay = 0,
        },
        finder = {
          keys = {
            toggle_or_open = "<cr>",
          },
        },
        definition = {
          edit = "<cr>",
        },
        ui = {
          border = "single",
          colors = {
            normal_bg = colors.base00,
          },
        },
      })
    end,
  },
  "AndrewRadev/splitjoin.vim",
  { "numToStr/Comment.nvim",       config = true },
  { "linrongbin16/gitlinker.nvim", config = true },
  { "lewis6991/gitsigns.nvim",     config = true },
  "f-person/git-blame.nvim",
  "matze/vim-move",
  "mg979/vim-visual-multi",
  "tpope/vim-sleuth",
  "tpope/vim-surround",
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      "tpope/vim-dadbod",
      { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    init = function()
      vim.g["db_ui_use_nerd_fonts"] = 1
    end,
  },
  {
    "iamcco/markdown-preview.nvim",
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
  },
  {
    "Shopify/shadowenv.vim",
    cond = function()
      return vim.fn.executable("shadowenv") == 1
    end,
  },
}
