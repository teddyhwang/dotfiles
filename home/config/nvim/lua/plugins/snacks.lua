return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  config = function()
    require("snacks").setup({
      bigfile = { enabled = true },
      dashboard = { enabled = true },
      dim = { enabled = true },
      explorer = { enabled = true },
      image = { force = true },
      indent = { enabled = true },
      input = { enabled = true },
      lazygit = {
        theme = {
          activeBorderColor = { fg = "Title", bold = true },
        },
      },
      picker = {
        transform = function(item)
          if item.file and item.file:match("%.rbi$") then
            item.score_add = -50
          end
          return item
        end,
        formatters = {
          file = {
            truncate = 60,
          },
        },
        win = {
          input = {
            keys = {
              ["<a-s>"] = { "flash", mode = { "n", "i" } },
              ["s"] = { "flash" },
            },
          },
        },
        actions = {
          flash = function(picker)
            require("flash").jump({
              pattern = "^",
              label = { after = { 0, 0 } },
              search = {
                mode = "search",
                exclude = {
                  function(win)
                    return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "snacks_picker_list"
                  end,
                },
              },
              action = function(match)
                local idx = picker.list:row2idx(match.pos[1])
                picker.list:_move(idx, true, true)
              end,
            })
          end,
        },
      },
      notifier = { enabled = true },
      quickfile = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = true },
      styles = {
        float = {
          border = "rounded",
          backdrop = 40,
        },
      },
      terminal = { enabled = true },
      toggle = { enabled = true },
      words = { enabled = true },
      zen = { enabled = true },
    })

    vim.g.snacks_animate = false

    -- Reduce indent line opacity (run after plugin loads)
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

    local function apply_indent_opacity()
      local opacity = 0.4 -- Adjust this value (0.0 - 1.0)

      local bg_hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
      local bg_r, bg_g, bg_b = 0, 0, 0
      if bg_hl.bg then
        bg_r, bg_g, bg_b = hex_to_rgb(bg_hl.bg)
      end

      apply_opacity_to_hl("SnacksIndent", "indent", bg_r, bg_g, bg_b, opacity)
      apply_opacity_to_hl("SnacksIndentScope", "scope", bg_r, bg_g, bg_b, opacity)
    end

    -- Apply when files are opened (when indent highlights are created) and on colorscheme change
    local augroup = vim.api.nvim_create_augroup("SnacksIndentOpacity", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
      group = augroup,
      callback = function()
        vim.schedule(apply_indent_opacity)
      end,
    })

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = augroup,
      callback = function()
        -- Reset stored colors on colorscheme change
        original_colors = {}
        vim.schedule(apply_indent_opacity)
      end,
    })
  end,
}
