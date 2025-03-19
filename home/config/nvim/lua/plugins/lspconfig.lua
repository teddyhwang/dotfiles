return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "folke/snacks.nvim",
    { "williamboman/mason.nvim", config = true },
    "stevearc/conform.nvim",
    { "zapling/mason-conform.nvim", config = true },
    "mfussenegger/nvim-lint",
    { "rshkarin/mason-nvim-lint", config = true },
    {
      "williamboman/mason-lspconfig.nvim",
      config = true,
    },
  },
  config = function()
    local lspconfig = require("lspconfig")
    local blink_cmp = require("blink.cmp")
    local lint = require("lint")
    local conform = require("conform")
    local icons = require("config.icons")
    local Snacks = require("snacks")

    for type, icon in pairs(icons.diagnostics) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    local prettier_filetypes = {
      "css",
      "graphql",
      "html",
      "javascript",
      "javascriptreact",
      "json",
      "less",
      "markdown",
      "scss",
      "typescript",
      "typescriptreact",
    }

    local prettier_formatters = function(filetypes)
      local formatters = {}
      for _, filetype in ipairs(filetypes) do
        formatters[filetype] = { "prettierd", "prettier", stop_after_first = true }
      end
      return formatters
    end

    conform.setup({
      default_format_opts = {
        lsp_format = "fallback",
      },
      format_on_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end
        return { timeout_ms = 1000, lsp_format = "fallback" }
      end,
      formatters_by_ft = vim.tbl_extend("force", prettier_formatters(prettier_filetypes), {
        lua = { "stylua" },
        sh = { "shfmt" },
        zsh = { "shfmt" },
        ["*"] = { "codespell" },
        ["_"] = { "trim_whitespace" },
      }),
    })

    Snacks.toggle.new({
      id = "format",
      name = "format",
      get = function()
        return not (vim.g.disable_autoformat or vim.b.disable_autoformat)
      end,
      set = function(state)
        if state then
          vim.b.disable_autoformat = false
          vim.g.disable_autoformat = false
        else
          vim.b.disable_autoformat = true
        end
      end,
    })

    lint.linters_by_ft = {
      yaml = { "yamllint" },
    }

    local default_config = {
      capabilities = blink_cmp.get_lsp_capabilities(),
    }

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter" }, {
      callback = function()
        lint.try_lint()
      end,
    })

    local servers = {
      html = { filetypes = { "html", "eruby" } },
      ts_ls = {},
      cssls = {},
      tailwindcss = {},
      eslint = {},
      graphql = {},
      jsonls = {},
      lua_ls = {
        on_init = function(client)
          if client.workspace_folders then
            local path = client.workspace_folders[1].name
            if
              vim.fn.filereadable(path .. "/.luarc.json") == 1 or vim.fn.filereadable(path .. "/.luarc.jsonc") == 1
            then
              return
            end
          end

          client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
            runtime = {
              version = "LuaJIT",
            },
            workspace = {
              checkThirdParty = false,
              library = {
                vim.env.VIMRUNTIME,
              },
            },
          })
        end,
        settings = {
          Lua = {},
        },
      },
      sorbet = {
        root_dir = lspconfig.util.root_pattern("sorbet/config"),
      },
      ruby_lsp = {
        init_options = {
          formatter = "rubocop",
        },
      },
      bashls = {
        filetypes = { "sh", "zsh" },
      },
      yamlls = {},
    }

    for server, config in pairs(servers) do
      lspconfig[server].setup(vim.tbl_deep_extend("force", default_config, config))
    end
  end,
}
