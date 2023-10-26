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
---@diagnostic disable-next-line: undefined-field
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
      {
        "levouh/tint.nvim",
        config = true,
      },
      {
        "RRethy/nvim-base16",
        lazy = false,
      },
      {
        "omnisyle/nvim-hidesig",
        lazy = false,
      },
    },
    build = ":TSUpdate",
    priority = 1000,
  },

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
  "tpope/vim-rhubarb",
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
  "airblade/vim-rooter",
  "folke/which-key.nvim",
  {
    "junegunn/fzf.vim",
    dependencies = {
      "junegunn/fzf",
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
  { "nvim-telescope/telescope.nvim", version = "*", dependencies = { "nvim-lua/plenary.nvim" } },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    cond = function()
      return vim.fn.executable("make") == 1
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
    },
  },
  "windwp/nvim-autopairs",
  {
    "windwp/nvim-ts-autotag",
    dependencies = { "nvim-treesitter" },
  },
  {
    "gelguy/wilder.nvim",
    dependencies = { "romgrk/fzy-lua-native" },
    build = ":UpdateRemotePlugins",
  },

  -- -- configuring lsp servers
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "folke/neodev.nvim",
      "gfanto/fzf-lsp.nvim",
      "jayp0521/mason-null-ls.nvim",
      "jose-elias-alvarez/null-ls.nvim",
      "jose-elias-alvarez/typescript.nvim",
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
  "ruanyl/vim-gh-line",
  "tpope/vim-fugitive",

  -- -- data
  "kristijanhusak/vim-dadbod-completion",
  "kristijanhusak/vim-dadbod-ui",
  "tpope/vim-dadbod",

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
          copilot_node_command = "node",
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
