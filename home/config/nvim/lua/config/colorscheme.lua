-- Auto-reload colorscheme from tinty

-- Default colorscheme: base16-seti
-- base00 = '#151718', base01 = '#282a2b', base02 = '#3b758c', base03 = '#41535b',
-- base04 = '#43a5d5', base05 = '#d6d6d6', base06 = '#eeeeee', base07 = '#ffffff',
-- base08 = '#cd3f45', base09 = '#db7b55', base0A = '#e6cd69', base0B = '#9fca56',
-- base0C = '#55dbbe', base0D = '#55b5db', base0E = '#a074c4', base0F = '#8a553f'

return function(colors)
  -- Helper to blend two hex colors (for subtle backgrounds)
  local function blend_colors(fg_color, bg_color, alpha)
    local function hex_to_rgb(hex)
      hex = hex:gsub("#", "")
      return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
    end
    local function rgb_to_hex(r, g, b)
      return string.format("#%02x%02x%02x", math.floor(r), math.floor(g), math.floor(b))
    end
    local fr, fg, fb = hex_to_rgb(fg_color)
    local br, bg, bb = hex_to_rgb(bg_color)
    local r = fr * alpha + br * (1 - alpha)
    local g = fg * alpha + bg * (1 - alpha)
    local b = fb * alpha + bb * (1 - alpha)
    return rgb_to_hex(r, g, b)
  end

  local handle_custom_highlights = function()
    local function is_light_theme()
      local bg = colors.base00:gsub("#", "")
      local r = tonumber(bg:sub(1, 2), 16)
      local g = tonumber(bg:sub(3, 4), 16)
      local b = tonumber(bg:sub(5, 6), 16)

      local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
      return luminance > 0.5
    end

    local highlights = {
      ["@symbol"] = { fg = colors.base09 },
      ["@variable"] = { fg = colors.base08 },
      ["@variable.member"] = { fg = colors.base08 },
      ["@function"] = { fg = colors.base08 },
      ["@keyword"] = { fg = colors.base0E },
      ["@property"] = { fg = colors.base08 },
      ["@parameter"] = { fg = colors.base08 },
      Title = { fg = colors.base09 },
      SnacksPickerInputBorder = { link = "Title" },
      TSFuncMacro = { link = "TSString" },
      TSType = { fg = colors.base0A },
      TSNamespace = { fg = colors.base0A },
      Identifier = { fg = colors.base08 },
      LineNr = { fg = colors.base03 },
      Pmenu = { bg = colors.base00, fg = colors.base05 },
      PmenuSbar = { bg = colors.base03, fg = colors.base03 },
      PmenuSel = { bg = colors.base02, fg = colors.base06 },
      PmenuThumb = { bg = colors.base09, fg = colors.base09 },
      VertSplit = { link = "LineNr" },
      -- Blink.cmp highlights
      BlinkCmpMenu = { bg = colors.base00, fg = colors.base05 },
      BlinkCmpMenuBorder = { link = "FloatBorder" },
      BlinkCmpMenuSelection = { bg = colors.base02, fg = colors.base06 },
      BlinkCmpLabel = { fg = colors.base05 },
      BlinkCmpLabelMatch = { fg = colors.base0D, bold = true },
      BlinkCmpKind = { link = "@text" },
      BlinkCmpDoc = { bg = colors.base00, fg = colors.base05 },
      BlinkCmpDocBorder = { link = "BlinkCmpMenuBorder" },
      FloatBorder = { link = "VertSplit" },
      HighlightedyankRegion = { bg = colors.base03 },
      WinSeparator = { fg = colors.base03 },
      MatchParen = { bg = blend_colors(colors.base02, colors.base00, 0.30) },
      -- Fix lualine section backgrounds to use StatusLine bg
      StatusLine = { bg = colors.base01, fg = colors.base04 },
      lualine_c_normal = { bg = colors.base01 },
      lualine_c_insert = { bg = colors.base01 },
      lualine_c_visual = { bg = colors.base01 },
      lualine_c_replace = { bg = colors.base01 },
      lualine_c_command = { bg = colors.base01 },
      lualine_c_inactive = { bg = colors.base01 },
      DiffAdd = { bg = blend_colors(colors.base0B, colors.base00, 0.15) },
      DiffDelete = { bg = blend_colors(colors.base08, colors.base00, 0.15), strikethrough = true },
      DiffChange = { bg = blend_colors(colors.base0A, colors.base00, 0.15) },
      DiffText = { bg = blend_colors(colors.base0C, colors.base00, 0.20), italic = true },
      Visual = { bg = is_light_theme() and colors.base02 or blend_colors(colors.base0D, colors.base00, 0.20) },
    }

    for k, v in pairs(highlights) do
      vim.api.nvim_set_hl(0, k, v)
    end
  end

  vim.api.nvim_create_autocmd("User", {
    pattern = "TintedColorsPost",
    callback = function()
      local tinted = require("tinted-colorscheme")
      colors = tinted.colors
      handle_custom_highlights()
    end,
  })

  handle_custom_highlights()
end
