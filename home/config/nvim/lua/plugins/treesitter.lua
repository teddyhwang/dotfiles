return {
  "nvim-treesitter/nvim-treesitter",
  dependencies = {
    "bfontaine/Brewfile.vim",
    "nvim-treesitter/nvim-treesitter-textobjects",
    "sle-c/nvim-hidesig",
    "tpope/vim-liquid",
    "tpope/vim-rails",
    "whatyouhide/vim-tmux-syntax",
    {
      "windwp/nvim-ts-autotag",
      config = true,
    },
  },
  build = ":TSUpdate",
  init = function()
    local treesitter_configs = require("nvim-treesitter.configs")
    local treesitter_parsers = require("nvim-treesitter.parsers")
    treesitter_configs.setup({
      highlight = {
        enable = true,
      },
      indent = {
        enable = true,
        disable = { "ruby" },
      },
      matchup = { enable = true },
      ensure_installed = {
        "bash",
        "dockerfile",
        "gitignore",
        "graphql",
        "html",
        "javascript",
        "json",
        "lua",
        "luadoc",
        "markdown",
        "markdown_inline",
        "python",
        "ruby",
        "svelte",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "yaml",
        "xml",
      },
      sync_install = false,
      ignore_install = {},
      auto_install = false,
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<c-space>",
          node_incremental = "<c-space>",
          scope_incremental = "<c-s>",
          node_decremental = "<M-space>",
        },
      },
      textobjects = {
        select = {
          enable = true,
          lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
          keymaps = {
            -- You can use the capture groups defined in textobjects.scm
            ["aa"] = "@parameter.outer",
            ["ia"] = "@parameter.inner",
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
          },
        },
        move = {
          enable = true,
          set_jumps = true, -- whether to set jumps in the jumplist
          goto_next_start = {
            ["]m"] = "@function.outer",
            ["]]"] = "@class.outer",
          },
          goto_next_end = {
            ["]M"] = "@function.outer",
            ["]["] = "@class.outer",
          },
          goto_previous_start = {
            ["[m"] = "@function.outer",
            ["[["] = "@class.outer",
          },
          goto_previous_end = {
            ["[M"] = "@function.outer",
            ["[]"] = "@class.outer",
          },
        },
        swap = {
          enable = true,
          swap_next = {
            ["<leader>a"] = "@parameter.inner",
          },
          swap_previous = {
            ["<leader>A"] = "@parameter.inner",
          },
        },
      },
      hidesig = {
        enable = true,
        opacity = 0.5,
        delay = 0,
      },
    })

    -- https://github.com/nvim-treesitter/nvim-treesitter/issues/655#issuecomment-1021160477
    local ft_to_lang = treesitter_parsers.ft_to_lang
    treesitter_parsers.ft_to_lang = function(ft)
      if ft == "zsh" then
        return "bash"
      end
      return ft_to_lang(ft)
    end
  end,
}
