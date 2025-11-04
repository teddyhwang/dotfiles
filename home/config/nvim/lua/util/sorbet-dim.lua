-- sorbet-dim.lua
-- Dims Sorbet type signatures in Ruby files using nvim 0.11+ treesitter APIs

local M = {}

-- Configuration
local config = {
  opacity = 0.5, -- 0.0 = invisible, 1.0 = normal
  delay = 200, -- ms delay for debounced updates
}

-- Namespace for our highlights
local ns = vim.api.nvim_create_namespace("sorbet_dim")

-- Timer for debouncing
local update_timer = nil

-- Cache for dimmed highlight groups
local hl_cache = {}

-- Cache for processed signature blocks per buffer
-- Format: { [bufnr] = { ["start_row:start_col:end_row:end_col"] = true } }
local sig_cache = {}

-- Convert decimal color to hex
local function dec_to_hex(dec)
  return string.format("#%06x", dec)
end

-- Convert hex to RGB components
local function hex_to_rgb(hex)
  hex = hex:gsub("#", "")
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

-- Blend color toward background
local function blend_color(fg_dec, opacity)
  if not fg_dec then
    return nil
  end

  local fg_hex = dec_to_hex(fg_dec)
  local fg_r, fg_g, fg_b = hex_to_rgb(fg_hex)

  -- Get background color
  local bg_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
  local bg_r, bg_g, bg_b = 0, 0, 0

  if bg_hl.bg then
    local bg_hex = dec_to_hex(bg_hl.bg)
    bg_r, bg_g, bg_b = hex_to_rgb(bg_hex)
  end

  -- Blend: new_color = fg * opacity + bg * (1 - opacity)
  local new_r = math.floor(fg_r * opacity + bg_r * (1 - opacity))
  local new_g = math.floor(fg_g * opacity + bg_g * (1 - opacity))
  local new_b = math.floor(fg_b * opacity + bg_b * (1 - opacity))

  return string.format("#%02x%02x%02x", new_r, new_g, new_b)
end

-- Get or create dimmed version of a highlight group
local function get_dimmed_hl(hl_name)
  -- Check cache
  local cache_key = hl_name .. "_" .. config.opacity
  if hl_cache[cache_key] then
    return hl_cache[cache_key]
  end

  -- Get the highlight definition (resolve links)
  local hl_def = vim.api.nvim_get_hl(0, { name = hl_name, link = false })

  -- Create dimmed version
  local dimmed_hl = {}

  if hl_def.fg then
    dimmed_hl.fg = blend_color(hl_def.fg, config.opacity)
  end

  -- Preserve other attributes
  if hl_def.bg then
    dimmed_hl.bg = hl_def.bg
  end
  if hl_def.bold then
    dimmed_hl.bold = true
  end
  if hl_def.italic then
    dimmed_hl.italic = true
  end
  if hl_def.underline then
    dimmed_hl.underline = true
  end

  -- Create unique highlight group name
  local dimmed_name = "SorbetDim_" .. hl_name:gsub("[^%w]", "_") .. "_" .. math.floor(config.opacity * 100)

  -- Set the highlight
  vim.api.nvim_set_hl(0, dimmed_name, dimmed_hl)

  -- Cache it
  hl_cache[cache_key] = dimmed_name

  return dimmed_name
end

-- Apply dimming to a Sorbet signature node
local function dim_sorbet_node(bufnr, node)
  local start_row, start_col, end_row, end_col = node:range()

  -- Create cache key for this signature
  local sig_key = string.format("%d:%d:%d:%d", start_row, start_col, end_row, end_col)

  -- Initialize buffer cache if needed
  if not sig_cache[bufnr] then
    sig_cache[bufnr] = {}
  end

  -- Skip if already processed
  if sig_cache[bufnr][sig_key] then
    return
  end

  -- Mark as processed
  sig_cache[bufnr][sig_key] = true

  -- Get all treesitter highlights in this range
  local parser = vim.treesitter.get_parser(bufnr, "ruby")
  if not parser then
    return
  end

  local tree = parser:parse()[1]
  if not tree then
    return
  end

  -- Get highlight query
  local query = vim.treesitter.query.get("ruby", "highlights")
  if not query then
    return
  end

  -- Track applied ranges to avoid overlaps
  local applied = {}

  -- Iterate through all highlight captures within the signature node
  for id, capture_node in query:iter_captures(node, bufnr, start_row, end_row + 1) do
    local capture_name = query.captures[id]
    local node_start_row, node_start_col, node_end_row, node_end_col = capture_node:range()

    -- Create key for deduplication
    local key = string.format("%d:%d:%d:%d", node_start_row, node_start_col, node_end_row, node_end_col)

    if not applied[key] then
      applied[key] = true

      -- Get the highlight group name
      local hl_group = "@" .. capture_name .. ".ruby"

      -- Get dimmed version
      local dimmed_hl = get_dimmed_hl(hl_group)

      -- Apply the dimmed highlight
      vim.api.nvim_buf_set_extmark(bufnr, ns, node_start_row, node_start_col, {
        end_row = node_end_row,
        end_col = node_end_col,
        hl_group = dimmed_hl,
        priority = 150, -- Higher than default syntax
      })
    end
  end
end

-- Clear cache and highlights for a buffer
local function clear_buffer_cache(bufnr)
  sig_cache[bufnr] = {}
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

-- Update highlights for visible portion of buffer (incremental)
local function update_visible_incremental()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Only process Ruby files
  if vim.bo[bufnr].filetype ~= "ruby" then
    return
  end

  -- Get visible range
  local start_line = vim.fn.line("w0") - 1
  local end_line = vim.fn.line("w$")

  -- Handle Sorbet sig blocks
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "ruby")
  if not ok or not parser then
    return
  end

  local trees = parser:parse()
  if not trees or #trees == 0 then
    return
  end

  local root = trees[1]:root()

  -- Query for sig definitions
  local query_text = [[
    (
      call
        method: (identifier) @sig_keyword
        block: [(block) (do_block)]
      (#eq? @sig_keyword "sig")
    ) @sig_def
  ]]

  local ok_query, query = pcall(vim.treesitter.query.parse, "ruby", query_text)
  if not ok_query then
    return
  end

  -- Execute query and dim matching nodes (only new ones due to cache)
  for id, node in query:iter_captures(root, bufnr, start_line, end_line) do
    if query.captures[id] == "sig_def" then
      dim_sorbet_node(bufnr, node)
    end
  end
end

-- Full update (clears cache and re-renders everything visible)
local function update_visible_full()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Only process Ruby files
  if vim.bo[bufnr].filetype ~= "ruby" then
    return
  end

  -- Clear cache and highlights
  clear_buffer_cache(bufnr)

  -- Re-render visible signatures
  update_visible_incremental()
end

-- Debounced incremental update
local function update_debounced()
  if update_timer then
    update_timer:stop()
  end

  update_timer = vim.defer_fn(function()
    update_visible_incremental()
  end, config.delay)
end

-- Setup function
function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  -- Create autocommands
  local group = vim.api.nvim_create_augroup("SorbetDim", { clear = true })

  -- Full update on buffer enter and initial load
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*.rb",
    callback = update_visible_incremental, -- Use incremental since cache is per-buffer
  })

  -- Full update when content changes
  vim.api.nvim_create_autocmd({ "BufWritePost", "TextChanged", "TextChangedI" }, {
    group = group,
    pattern = "*.rb",
    callback = update_visible_full,
  })

  -- Incremental update on scroll/cursor movement (debounced)
  vim.api.nvim_create_autocmd({ "CursorMoved", "InsertLeave" }, {
    group = group,
    pattern = "*.rb",
    callback = update_debounced,
  })

  -- Full refresh on colorscheme change
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      hl_cache = {} -- Clear highlight cache
      -- Clear all buffer caches and re-render
      for bufnr, _ in pairs(sig_cache) do
        if vim.api.nvim_buf_is_valid(bufnr) then
          clear_buffer_cache(bufnr)
        end
      end
      sig_cache = {}
      update_visible_incremental()
    end,
  })

  -- Clean up cache when buffer is deleted
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    pattern = "*.rb",
    callback = function(args)
      sig_cache[args.buf] = nil
    end,
  })
end

return M
