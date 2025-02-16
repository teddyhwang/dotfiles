return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    { "williamboman/mason.nvim",  config = true },
    "stevearc/conform.nvim",
    "mfussenegger/nvim-lint",
    { "rshkarin/mason-nvim-lint", config = true },
    {
      "williamboman/mason-lspconfig.nvim",
      opts = {
        automatic_installation = false,
        ensure_installed = {
          "bashls",
          "cssls",
          "graphql",
          "html",
          "jsonls",
          "lua_ls",
          "tailwindcss",
          "ts_ls",
          "yamlls",
        },
      },
    },
  },
  config = function()
    local lspconfig = require("lspconfig")
    local cmp_nvim_lsp = require("cmp_nvim_lsp")
    local lint = require("lint")
    local format = require("conform")
    local icons = require("config.icons")

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

    local server_filetypes = {
      html = { "html" },
      cssls = { "css", "scss", "less" },
      graphql = { "graphql" },
      jsonls = { "json" },
    }

    local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

    local function on_attach(client, bufnr)
      if client.supports_method("textDocument/formatting") then
        vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
        vim.api.nvim_create_autocmd("BufWritePre", {
          group = augroup,
          buffer = bufnr,
          callback = function(args)
            if vim.tbl_contains(prettier_filetypes, vim.bo[bufnr].filetype) then
              format({ bufnr = args.buf })
            else
              vim.lsp.buf.format({ bufnr = bufnr })
            end
          end,
        })
      end
    end

    local default_config = {
      capabilities = cmp_nvim_lsp.default_capabilities(),
      on_attach = on_attach,
    }

    local function disable_formatting(client, bufnr)
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
      on_attach(client, bufnr)
    end

    local function prettier_formatters(filetypes)
      local formatters = {}
      for _, filetype in ipairs(filetypes) do
        formatters[filetype] = { "prettierd", "prettier", stop_after_first = true }
      end
      return formatters
    end

    format.setup({
      formatters_by_ft = vim.tbl_extend("force",
        prettier_formatters(prettier_filetypes),
        { lua = { "stylua" } }
      ),
    })

    lint.linters_by_ft = {
      yaml = { "yamllint" },
    }

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter" }, {
      callback = function()
        lint.try_lint()
      end,
    })

    local servers = {
      html = { filetypes = { "html", "eruby" } },
      ts_ls = { on_attach = disable_formatting },
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
        capabilities = vim.tbl_deep_extend("force", default_config.capabilities, {
          textDocument = {
            references = true,
            definition = true,
            implementation = true,
          },
        }),
      },
      bashls = {},
      yamlls = {},
    }

    for server, filetypes in pairs(server_filetypes) do
      for _, filetype in ipairs(filetypes) do
        if vim.tbl_contains(prettier_filetypes, filetype) then
          servers[server] = vim.tbl_deep_extend("force", servers[server] or {}, { on_attach = disable_formatting })
          break
        end
      end
    end

    for server, config in pairs(servers) do
      lspconfig[server].setup(vim.tbl_deep_extend("force", default_config, config))
    end
  end,
}
