return {
  "tpope/vim-sensible",
  {
    "akinsho/bufferline.nvim",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("restart").bufferline()
    end,
  },
  { "NvChad/nvim-colorizer.lua", config = true },
  "sitiom/nvim-numbertoggle",
  "kristijanhusak/vim-carbon-now-sh",
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = "cd app && yarn install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
    ft = { "markdown" },
  },
  {
    "machakann/vim-highlightedyank",
    init = function()
      vim.g["highlightedyank_highlight_duration"] = 100
    end,
  },
  {
    "echasnovski/mini.ai",
    version = "*",
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
    init = function()
      vim.g["test#strategy"] = "vimux"
    end,
  },
  "vim-test/vim-test",
  "AndrewRadev/undoquit.vim",
  "dhruvasagar/vim-zoom",
  {
    "simeji/winresizer",
    init = function()
      vim.g["winresizer_horiz_resize"] = 1
      vim.g["winresizer_vert_resize"] = 3
    end,
  },
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
  },
  "vim-scripts/Tabmerge",
  {
    "airblade/vim-rooter",
    init = function()
      vim.g["rooter_patterns"] = { ".git", ".git/", "Gemfile", "package.json", "CHANGELOG.md" }
    end,
  },
  {
    "echasnovski/mini.pairs",
    event = "VeryLazy",
    opts = {
      modes = { insert = true, command = true, terminal = false },
      skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
      skip_ts = { "string" },
      skip_unbalanced = true,
      markdown = true,
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
    "folke/trouble.nvim",
    opts = {
      modes = {
        lsp = {
          win = { position = "right" },
        },
      },
    },
  },
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = true,
  },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    config = true,
  },
  {
    "MagicDuck/grug-far.nvim",
    opts = { headerMaxWidth = 80 },
    cmd = "GrugFar",
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
        lightbulb = {
          enable = false,
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
  { "numToStr/Comment.nvim", config = true },
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "folke/snacks.nvim",
    },
    opts = {
      picker = "snacks",
    },
  },
  { "linrongbin16/gitlinker.nvim", config = true },
  { "lewis6991/gitsigns.nvim", config = true },
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
      vim.g["db_ui_use_nvim_notify"] = 1
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    config = true,
  },
  {
    "Shopify/shadowenv.vim",
    cond = function()
      return vim.fn.executable("shadowenv") == 1
    end,
  },
}
