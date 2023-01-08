local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({ "git", "clone", "--depth", "1", "https://github.com/wbthomason/packer.nvim", install_path })
    vim.cmd([[packadd packer.nvim]])
    return true
  end
  return false
end
local packer_bootstrap = ensure_packer()

vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins-setup.lua source <afile> | PackerSync
  augroup end
]])

local status, packer = pcall(require, "packer")
if not status then
  return
end

packer.startup(function(use)
  -- defaults
  use("wbthomason/packer.nvim")

  use("nvim-lua/plenary.nvim")
  use("tpope/vim-sensible")

  -- appearance
  -- -- nvim
  use({
    "nvim-treesitter/nvim-treesitter",
    run = function()
      local ts_update = require("nvim-treesitter.install").update({ with_sync = true })
      ts_update()
    end,
  })
  use({
    "nvim-treesitter/nvim-treesitter-textobjects",
    after = "nvim-treesitter",
  })

  -- -- theme
  use("RRethy/nvim-base16")
  use("nvim-lualine/lualine.nvim")
  use("tinted-theming/base16-vim")

  -- -- panes
  use("blueyed/vim-diminactive")
  use("lewis6991/gitsigns.nvim")
  use("lukas-reineke/indent-blankline.nvim") -- indentation guides
  use("vim-scripts/RelativeNumberCurrentWindow")

  -- -- editor
  use("machakann/vim-highlightedyank")
  use("norcalli/nvim-colorizer.lua")
  use({
    "andymass/vim-matchup", -- if end matches
    setup = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
    end,
  })

  -- -- language support
  use("tpope/vim-liquid")
  use("tpope/vim-rails")
  use("whatyouhide/vim-tmux-syntax")
  use("omnisyle/nvim-hidesig")

  -- window management
  -- -- terminal
  use("christoomey/vim-tmux-navigator")
  use("preservim/vimux")
  use("tmux-plugins/vim-tmux")
  use("tpope/vim-rhubarb")
  use("vim-test/vim-test")
  use("voldikss/vim-floaterm")

  -- -- panes
  use("AndrewRadev/undoquit.vim")
  use("dhruvasagar/vim-zoom")
  use("simeji/winresizer")
  use("tpope/vim-obsession")
  use("vim-scripts/Tabmerge")

  -- -- navigation
  use("airblade/vim-rooter")
  use("junegunn/fzf")
  use("junegunn/fzf.vim")
  use("nvim-tree/nvim-tree.lua")
  use("nvim-tree/nvim-web-devicons")
  use({ "nvim-telescope/telescope-fzf-native.nvim", run = "make" })
  use({ "nvim-telescope/telescope.nvim", branch = "0.1.x" })

  -- editor
  -- -- autocompletion
  use("hrsh7th/nvim-cmp")
  use("hrsh7th/cmp-buffer")
  use("hrsh7th/cmp-path")
  use("windwp/nvim-autopairs")
  use({
    "windwp/nvim-ts-autotag",
    after = "nvim-treesitter",
  })

  -- -- snippets
  use("L3MON4D3/LuaSnip")
  use("rafamadriz/friendly-snippets")
  use("saadparwaiz1/cmp_luasnip")

  -- -- managing & installing lsp servers, linters & formatters
  use("williamboman/mason-lspconfig.nvim")
  use("williamboman/mason.nvim")

  -- -- configuring lsp servers
  use("hrsh7th/cmp-nvim-lsp")
  use("jose-elias-alvarez/typescript.nvim")
  use("neovim/nvim-lspconfig")
  use("onsails/lspkind.nvim")
  use({ "glepnir/lspsaga.nvim", branch = "main" })

  -- -- formatting & linting
  use("jayp0521/mason-null-ls.nvim")
  use("jose-elias-alvarez/null-ls.nvim")
  use("tpope/vim-sleuth")
  use("tpope/vim-surround")

  -- -- moving
  use("AndrewRadev/splitjoin.vim")
  use("fedepujol/move.nvim")
  use("inkarkat/vim-ReplaceWithRegister")
  use("mg979/vim-visual-multi") -- multiple cursors
  use("numToStr/Comment.nvim")

  -- -- git
  use("ruanyl/vim-gh-line")
  use("tpope/vim-fugitive")

  -- -- data
  use("kristijanhusak/vim-dadbod-completion")
  use("kristijanhusak/vim-dadbod-ui")
  use("tpope/vim-dadbod")

  -- -- editing
  use("github/copilot.vim")
  use({
    "iamcco/markdown-preview.nvim",
    run = function()
      vim.fn["mkdp#util#install"]()
    end,
  })

  if vim.fn.executable("shadowenv") == 1 then
    use("Shopify/shadowenv.vim")
  end

  if packer_bootstrap then
    require("packer").sync()
  end
end)
