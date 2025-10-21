return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "folke/snacks.nvim",
    { "williamboman/mason.nvim", config = true },
    "stevearc/conform.nvim",
    {
      "zapling/mason-conform.nvim",
      config = {
        ignore_install = { "rubocop" },
      },
    },
    "mfussenegger/nvim-lint",
    { "rshkarin/mason-nvim-lint", config = true },
    {
      "williamboman/mason-lspconfig.nvim",
      config = true,
    },
  },
  config = function()
    local blink_cmp = require("blink.cmp")
    local lint = require("lint")
    local conform = require("conform")
    local icons = require("config.icons")
    local Snacks = require("snacks")

    vim.diagnostic.config({
      virtual_text = true,
      virtual_lines = false,
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = icons.diagnostics.Error,
          [vim.diagnostic.severity.WARN] = icons.diagnostics.Warn,
          [vim.diagnostic.severity.INFO] = icons.diagnostics.Info,
          [vim.diagnostic.severity.HINT] = icons.diagnostics.Hint,
        },
      },
      underline = true,
      update_in_insert = false,
      severity_sort = true,
    })

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

        local filetype = vim.bo[bufnr].filetype
        if filetype == "ruby" then
          return {
            timeout_ms = 2000,
            lsp_format = "prefer",
          }
        end

        return { timeout_ms = 2000, lsp_format = "fallback" }
      end,
      formatters_by_ft = vim.tbl_extend("force", prettier_formatters(prettier_filetypes), {
        lua = { "stylua" },
        sh = { "shfmt" },
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

          client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua or {}, {
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
      ruby_lsp = {
        init_options = {
          formatter = "rubocop",
        },
      },
      yamlls = {},
    }

    for server, config in pairs(servers) do
      vim.lsp.config(server, vim.tbl_deep_extend("force", default_config, config))
      vim.lsp.enable(server)
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "ruby",
      callback = function(args)
        local is_sorbet_project = vim.fs.root(args.buf, { "sorbet/config" })
        if is_sorbet_project then
          vim.lsp.enable("sorbet", args.buf)
        end
      end,
    })
  end,
}
