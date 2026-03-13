return {
  {
    "tadaa/vimade",
    opts = function()
      local function get_tint()
        local ok, tinted = pcall(require, "tinted-nvim")
        if ok then
          local colors = tinted.get_palette()
          if colors then
            local hex = colors.base01:gsub("#", "")
            return {
              bg = {
                rgb = {
                  tonumber(hex:sub(1, 2), 16),
                  tonumber(hex:sub(3, 4), 16),
                  tonumber(hex:sub(5, 6), 16),
                },
                intensity = 0.5,
              },
            }
          end
        end
        return {}
      end

      return {
        recipe = { "default", { animate = false } },
        ncmode = "windows",
        fadelevel = 0.6,
        tint = get_tint,
        enablefocusfading = true,
      }
    end,
  },
}
