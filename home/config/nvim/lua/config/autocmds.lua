-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Hide colorcolumn and cursorline in special buffers
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  callback = function()
    if vim.bo.buftype ~= "" then
      vim.opt_local.colorcolumn = ""
      vim.opt_local.cursorline = false
    else
      vim.opt_local.colorcolumn = "80,120"
      vim.opt_local.cursorline = true
    end
  end,
})

-- Auto-resize splits when vim is resized
vim.api.nvim_create_autocmd("VimResized", {
  pattern = "*",
  callback = function()
    vim.cmd("wincmd =")
  end,
})

-- Start in insert mode for terminal buffers
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "term://*",
  command = "startinsert",
})

-- Filetype mappings
vim.filetype.add({
  extension = {
    rbi = "ruby",
    graphql = "graphql",
    jsx = "javascript.jsx",
    plist = "xml",
    ejson = "json",
  },
  pattern = {
    [".*%.shared%.gitconfig"] = "gitconfig",
  },
})

-- Auto-reload files when changed externally
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
  pattern = "*",
  callback = function()
    if vim.fn.mode() ~= "c" and vim.bo.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

-- Command aliases
local command_aliases = {
  WQ = "wq",
  Wq = "wq",
  Wa = "wa",
  W = "w",
  Q = "q",
  Qa = "qa",
  Ex = "Oil %:p:h",
  Vs = "vs",
  Vex = "vs | Oil %:p:h",
  VEx = "vs | Oil %:p:h",
  Se = "sp | Oil %:p:h",
  Sex = "sp | Oil %:p:h",
  SEx = "sp | Oil %:p:h",
  Tabe = "tabe",
}

for alias, cmd in pairs(command_aliases) do
  vim.api.nvim_create_user_command(alias, cmd, {})
end

-- Conditionally enable Sorbet LSP for Ruby projects with sorbet/config
vim.api.nvim_create_autocmd("FileType", {
  pattern = "ruby",
  callback = function(args)
    local is_sorbet_project = vim.fs.root(args.buf, { "sorbet/config" })
    if is_sorbet_project then
      vim.lsp.enable("sorbet")
    end
  end,
})

-- Reduce indent line opacity
local indent_opacity = require("util.indent-opacity")

vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    vim.schedule(indent_opacity.apply)
  end,
})

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    indent_opacity.reset()
    vim.schedule(indent_opacity.apply)
  end,
})

-- Lighten background on focus lost (for areas vimade doesn't cover)
local focus_bg = (function()
  local function hex_to_rgb(hex)
    hex = hex:gsub("#", "")
    return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
  end

  local function rgb_to_hex(r, g, b)
    return string.format("#%02x%02x%02x", math.floor(r), math.floor(g), math.floor(b))
  end

  local function blend(fg_hex, bg_hex, alpha)
    local fr, fg, fb = hex_to_rgb(fg_hex)
    local br, bg, bb = hex_to_rgb(bg_hex)
    return rgb_to_hex(fr * alpha + br * (1 - alpha), fg * alpha + bg * (1 - alpha), fb * alpha + bb * (1 - alpha))
  end

  local function get_colors()
    local ok, tinted = pcall(require, "tinted-nvim")
    if ok then
      local colors = tinted.get_palette()
      if colors then
        return colors
      end
    end
    return nil
  end

  local function set_unfocused()
    local colors = get_colors()
    if not colors then
      return
    end
    local dimmed_bg = blend(colors.base01, colors.base00, 0.5)
    vim.api.nvim_set_hl(0, "Normal", { bg = dimmed_bg, fg = colors.base05 })
  end

  local function set_focused()
    local colors = get_colors()
    if not colors then
      return
    end
    vim.api.nvim_set_hl(0, "Normal", { bg = colors.base00, fg = colors.base05 })
  end

  return { set_unfocused = set_unfocused, set_focused = set_focused }
end)()

vim.api.nvim_create_autocmd("FocusLost", {
  callback = focus_bg.set_unfocused,
})

vim.api.nvim_create_autocmd("FocusGained", {
  callback = focus_bg.set_focused,
})

-- Dim sorbet signatures
require("util.sorbet-dim").setup({
  opacity = 0.5,
  delay = 200,
})
