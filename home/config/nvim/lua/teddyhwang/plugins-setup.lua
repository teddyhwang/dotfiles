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
      "nvim-treesitter/nvim-treesitter-textobjects",
      "RRethy/nvim-base16",
      "nvim-lualine/lualine.nvim",
      "tinted-theming/base16-vim",
      "omnisyle/nvim-hidesig",
      "tpope/vim-liquid",
      "tpope/vim-rails",
      "whatyouhide/vim-tmux-syntax",
    },
    config = function()
      pcall(require("nvim-treesitter.install").update({ with_sync = true }))
    end,
    build = ":TSUpdate",
    priority = 1000,
  },
  "bfontaine/Brewfile.vim",

  -- -- panes
  "levouh/tint.nvim",
  "lewis6991/gitsigns.nvim",
  "lukas-reineke/indent-blankline.nvim", -- indentation guides
  "jeffkreeftmeijer/vim-numbertoggle",
  "kristijanhusak/vim-carbon-now-sh",

  -- -- editor
  "machakann/vim-highlightedyank",
  "NvChad/nvim-colorizer.lua",
  {
    "andymass/vim-matchup", -- if end matches
    init = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
    end,
  },

  -- window management
  -- -- terminal
  "christoomey/vim-tmux-navigator",
  "preservim/vimux",
  "tmux-plugins/vim-tmux",
  "tpope/vim-rhubarb",
  "vim-test/vim-test",
  "voldikss/vim-floaterm",

  -- -- panes
  "AndrewRadev/undoquit.vim",
  "dhruvasagar/vim-zoom",
  "simeji/winresizer",
  "tpope/vim-obsession",
  "vim-scripts/Tabmerge",

  -- -- navigation
  "airblade/vim-rooter",
  "folke/which-key.nvim",
  "junegunn/fzf",
  "junegunn/fzf.vim",
  "nvim-tree/nvim-tree.lua",
  "nvim-tree/nvim-web-devicons",
  { "nvim-telescope/telescope.nvim", version = "*", dependencies = { "nvim-lua/plenary.nvim" } },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    cond = function()
      return vim.fn.executable("make") == 1
    end,
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
  "jose-elias-alvarez/typescript.nvim",
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "jayp0521/mason-null-ls.nvim",
      "jose-elias-alvarez/null-ls.nvim",
      { "j-hui/fidget.nvim", opts = {} },
      "folke/neodev.nvim",
      "gfanto/fzf-lsp.nvim",
    },
  },
  "onsails/lspkind.nvim",
  {
    "glepnir/lspsaga.nvim",
    event = "BufRead",
    dependencies = {
      { "nvim-tree/nvim-web-devicons" },
      { "nvim-treesitter/nvim-treesitter" },
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
  "numToStr/Comment.nvim",

  -- -- git
  "ruanyl/vim-gh-line",
  "tpope/vim-fugitive",

  -- -- data
  "kristijanhusak/vim-dadbod-completion",
  "kristijanhusak/vim-dadbod-ui",
  "tpope/vim-dadbod",

  -- -- editing
  "github/copilot.vim",
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
