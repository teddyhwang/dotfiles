-- Reduce indent line opacity for subtle appearance
local M = {}

local original_colors = {}

local function hex_to_rgb(hex)
  local hex_str = string.format("#%06x", hex)
  return tonumber(hex_str:sub(2, 3), 16), tonumber(hex_str:sub(4, 5), 16), tonumber(hex_str:sub(6, 7), 16)
end

local function blend_with_bg(r, g, b, bg_r, bg_g, bg_b, opacity)
  return math.floor(r * opacity + bg_r * (1 - opacity)),
    math.floor(g * opacity + bg_g * (1 - opacity)),
    math.floor(b * opacity + bg_b * (1 - opacity))
end

local function apply_opacity_to_hl(hl_name, cache_key, bg_r, bg_g, bg_b, opacity)
  local hl = vim.api.nvim_get_hl(0, { name = hl_name, link = false })
  if not hl.fg then
    return
  end

  if not original_colors[cache_key] then
    original_colors[cache_key] = hl.fg
  end

  local r, g, b = hex_to_rgb(original_colors[cache_key])
  local new_r, new_g, new_b = blend_with_bg(r, g, b, bg_r, bg_g, bg_b, opacity)
  vim.api.nvim_set_hl(0, hl_name, { fg = string.format("#%02x%02x%02x", new_r, new_g, new_b) })
end

function M.apply()
  local opacity = 0.4

  local bg_hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local bg_r, bg_g, bg_b = 0, 0, 0
  if bg_hl.bg then
    bg_r, bg_g, bg_b = hex_to_rgb(bg_hl.bg)
  end

  apply_opacity_to_hl("SnacksIndent", "indent", bg_r, bg_g, bg_b, opacity)
  apply_opacity_to_hl("SnacksIndentScope", "scope", bg_r, bg_g, bg_b, opacity)
end

function M.reset()
  original_colors = {}
end

return M
