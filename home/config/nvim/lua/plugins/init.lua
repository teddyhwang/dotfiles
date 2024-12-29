return {
  "tpope/vim-sensible",
  {
    "stevearc/dressing.nvim",
    opts = {
      input = {
        relative = "editor",
      },
    },
  },
  { "seblj/nvim-tabline",      config = true },
  { "lewis6991/gitsigns.nvim", config = true },
  "sitiom/nvim-numbertoggle",
  "kristijanhusak/vim-carbon-now-sh",
  {
    "j-hui/fidget.nvim",
    config = true,
  },
  {
    "machakann/vim-highlightedyank",
    init = function()
      vim.g["highlightedyank_highlight_duration"] = 100
    end,
  },
  {
    "NvChad/nvim-colorizer.lua",
    config = true,
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
  "tmux-plugins/vim-tmux",
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
    "nvim-tree/nvim-tree.lua",
    opts = {
      hijack_directories = {
        enable = false,
        auto_open = false,
      },
      hijack_netrw = false,
      actions = {
        open_file = {
          window_picker = {
            enable = false,
          },
        },
      },
    },
    init = function()
      vim.g["loaded_netrw"] = 1
      vim.g["loaded_netrwPlugin"] = 1
    end,
  },
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      fzf_colors = true,
    },
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
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = true,
  },
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      suggestion = { enabled = false, auto_trigger = true },
      panel = { enabled = false },
      copilot_node_command = "/opt/homebrew/bin/node",
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
  "f-person/git-blame.nvim",
  "inkarkat/vim-ReplaceWithRegister",
  "matze/vim-move",
  "mg979/vim-visual-multi",
  "tpope/vim-fugitive",
  "tpope/vim-rhubarb",
  "tpope/vim-sleuth",
  "tpope/vim-surround",
  { "numToStr/Comment.nvim",       config = true },
  { "linrongbin16/gitlinker.nvim", config = true },
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
