local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },
    "tpope/vim-sensible",
    {
      "nvim-lualine/lualine.nvim",
      dependencies = {
        "nvim-tree/nvim-web-devicons",
        "RRethy/nvim-base16",
      },
      init = function()
        local base16 = require("base16-colorscheme")
        local lualine = require("lualine")
        local setup_colors = require("config.colorscheme")
        local setup_lualine = require("lualine_init")
        setup_colors(base16)
        setup_lualine(lualine)
      end,
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
    { "lewis6991/gitsigns.nvim", config = true },
    {
      "lukas-reineke/indent-blankline.nvim",
      main = "ibl",
      config = {
        indent = {
          char = "│",
          highlight = "IblIndent",
        },
        scope = {
          highlight = "IblScope",
        },
      },
    },
    "jeffkreeftmeijer/vim-numbertoggle",
    "kristijanhusak/vim-carbon-now-sh",
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
      "junegunn/fzf.vim",
      dependencies = {
        "junegunn/fzf",
        { "echasnovski/mini.nvim", version = false },
      },
      init = function()
        vim.g["fzf_layout"] = {
          window = {
            width = 1,
            height = 0.4,
            yoffset = 1,
            border = "horizontal",
          },
        }
      end,
    },
    {
      "nvim-tree/nvim-tree.lua",
      config = {
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
      config = {
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
      dependencies = "zbirenbaum/copilot-cmp",
      config = function()
        require("copilot_cmp").setup({
          formatters = {
            insert_text = require("copilot_cmp.format").format_existing_text,
          },
        })
      end,
    },
    {
      "nvimtools/none-ls.nvim",
      dependencies = {
        "lukas-reineke/lsp-format.nvim",
      },
      config = function()
        local lsp_format = require("lsp-format")
        local null_ls = require("null-ls")
        lsp_format.setup({})

        local formatting = null_ls.builtins.formatting
        local diagnostics = null_ls.builtins.diagnostics
        null_ls.setup({
          sources = {
            formatting.prettierd.with({
              filetypes = {
                "css",
                "graphql",
                "html",
                "less",
                "markdown",
                "scss",
              },
            }),
            formatting.stylua,
            formatting.stylelint,
            diagnostics.stylelint,
            diagnostics.yamllint,
          },
          on_attach = lsp_format.on_attach,
        })
      end,
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
    {
      "jay-babu/mason-null-ls.nvim",
      config = {
        automatic_installation = true,
        ensure_installed = {
          "eslint-lsp",
          "prettier",
          "prettierd",
          "stylua",
          "stylelint",
          "yamlfmt",
          "yamllint",
        },
      },
    },
    {
      "williamboman/mason-lspconfig.nvim",
      config = {
        automatic_installation = true,
        ensure_installed = {
          "bashls",
          "cssls",
          "emmet_ls",
          "graphql",
          "html",
          "jsonls",
          "lua_ls",
          "ruby_lsp",
          "stylelint_lsp",
          "tailwindcss",
          "ts_ls",
          "yamlls",
        },
      },
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
    { "numToStr/Comment.nvim", config = true },
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
  },
})
