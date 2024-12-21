local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local status, lazy = pcall(require, "lazy")
if not status then
  return
end

lazy.setup({
  -- defaults
  "tpope/vim-sensible",

  -- appearance
  -- -- nvim
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = {
      "bfontaine/Brewfile.vim",
      "nvim-lualine/lualine.nvim",
      "nvim-treesitter/nvim-treesitter-textobjects",
      "tpope/vim-liquid",
      "tpope/vim-rails",
      "whatyouhide/vim-tmux-syntax",
      "RRethy/nvim-base16",
    },
    build = ":TSUpdate",
    priority = 1000,
  },

  {
    "sle-c/nvim-hidesig",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
  },

  {
    "stevearc/dressing.nvim",
    opts = {
      input = {
        relative = "editor",
      },
    },
  },

  { "seblj/nvim-tabline", config = true },

  -- -- panes
  {
    "lewis6991/gitsigns.nvim",
    config = true,
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {},
  },
  "jeffkreeftmeijer/vim-numbertoggle",
  "kristijanhusak/vim-carbon-now-sh",

  -- -- editor
  {
    "machakann/vim-highlightedyank",
    init = function()
      vim.g.highlightedyank_highlight_duration = 100
    end,
  },
  {
    "NvChad/nvim-colorizer.lua",
    config = true,
  },
  {
    "andymass/vim-matchup", -- if end matches
    init = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
    end,
  },

  -- window management
  -- -- terminal
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
      vim.g.floaterm_autoclose = 1
      vim.g.floaterm_gitcommit = "floaterm"
      vim.g.floaterm_height = 0.8
      vim.g.floaterm_keymap_new = "<F4>"
      vim.g.floaterm_keymap_next = "<F2>"
      vim.g.floaterm_keymap_prev = "<F3>"
      vim.g.floaterm_keymap_toggle = "<F1>"
      vim.g.floaterm_opener = "vsplit"
      vim.g.floaterm_width = 0.8
    end,
  },

  -- -- panes
  "AndrewRadev/undoquit.vim",
  "dhruvasagar/vim-zoom",
  {
    "simeji/winresizer",
    init = function()
      vim.g.winresizer_horiz_resize = 1
      vim.g.winresizer_vert_resize = 3
    end,
  },
  "tpope/vim-obsession",
  "vim-scripts/Tabmerge",

  -- -- navigation
  {
    "airblade/vim-rooter",
    init = function()
      vim.g.rooter_patterns = { ".git", ".git/", "Gemfile", "package.json", "CHANGELOG.md" }
    end,
  },
  "folke/which-key.nvim",
  {
    "junegunn/fzf.vim",
    dependencies = {
      "junegunn/fzf",
      { "echasnovski/mini.nvim", version = false },
    },
    init = function()
      vim.g.fzf_layout = {
        ["window"] = {
          ["width"] = 1,
          ["height"] = 0.4,
          ["yoffset"] = 1,
          ["border"] = "horizontal",
        },
      }
    end,
  },
  "nvim-tree/nvim-tree.lua",
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
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

  -- editor
  -- -- autocompletion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-nvim-lsp",
      "L3MON4D3/LuaSnip",
      "rafamadriz/friendly-snippets",
      "saadparwaiz1/cmp_luasnip",
      "nvim-lua/plenary.nvim",
    },
  },
  "windwp/nvim-autopairs",
  {
    "windwp/nvim-ts-autotag",
    dependencies = { "nvim-treesitter" },
  },
  {
    "gelguy/wilder.nvim",
    dependencies = {
      "romgrk/fzy-lua-native",
      "nvim-tree/nvim-web-devicons",
    },
    build = function()
      vim.cmd([[python3 -m pip install --user --upgrade pynvim]])
      vim.cmd([[UpdateRemotePlugins]])
    end,
  },

  -- -- configuring lsp servers
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "folke/neodev.nvim",
      "gfanto/fzf-lsp.nvim",
      "jay-babu/mason-null-ls.nvim",
      "lukas-reineke/lsp-format.nvim",
      "nvimtools/none-ls.nvim",
      "onsails/lspkind.nvim",
      "williamboman/mason-lspconfig.nvim",
      "williamboman/mason.nvim",
      {
        "j-hui/fidget.nvim",
        tag = "legacy",
        config = true,
      },
      {
        "glepnir/lspsaga.nvim",
        event = "BufRead",
        dependencies = {
          { "nvim-tree/nvim-web-devicons" },
          { "nvim-treesitter/nvim-treesitter" },
        },
      },
    },
  },

  -- -- formatting & linting
  "tpope/vim-sleuth",
  "tpope/vim-surround",

  -- -- moving
  "AndrewRadev/splitjoin.vim",
  "matze/vim-move",
  "inkarkat/vim-ReplaceWithRegister",
  "mg979/vim-visual-multi", -- multiple cursors
  {
    "numToStr/Comment.nvim",
    config = true,
  },

  -- -- git
  {
    "linrongbin16/gitlinker.nvim",
    config = true,
  },
  "tpope/vim-fugitive",
  "tpope/vim-rhubarb",
  "f-person/git-blame.nvim",

  -- -- data
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    init = function()
      vim.g.db_ui_use_nerd_fonts = 1
    end,
  },

  -- -- editing
  {
    "zbirenbaum/copilot-cmp",
    dependencies = {
      {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        event = "InsertEnter",
        opts = {
          suggestion = { enabled = false, auto_trigger = true },
          panel = { enabled = false },
          copilot_node_command = "/opt/homebrew/bin/node",
        },
      },
    },
    config = function()
      require("copilot_cmp").setup({
        formatters = {
          insert_text = require("copilot_cmp.format").format_existing_text,
        },
      })
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
})
