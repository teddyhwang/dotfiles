-- Personal keybinding overrides. Omarchy's defaults load first, so anything
-- already bound must be released with hl.unbind before it can be rebound.
-- See current bindings: omarchy menu keybindings --print

-- Vim-style window focus. All three of J/K/L ship bound by Omarchy.
hl.unbind("SUPER + J") -- was: Toggle window split (moved to SUPER + BACKSLASH)
hl.unbind("SUPER + K") -- was: Keybindings (moved to SUPER + SLASH)
hl.unbind("SUPER + L") -- was: Toggle workspace layout (left unbound)

o.bind("SUPER + H", "Move window focus left", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Move window focus down", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Move window focus up", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + L", "Move window focus right", hl.dsp.focus({ direction = "r" }))

-- Vim-style window swapping. Omarchy's arrow-key versions stay bound too.
o.bind("SUPER + SHIFT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))
o.bind("SUPER + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))

-- New homes for the defaults displaced above. SUPER + Q always closes windows.
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

-- SUPER + W closes the tab in full browsers, like Cmd+W on macOS, and closes
-- the window everywhere else. Browser tags come from Omarchy's
-- default/hypr/apps/browser.lua; dynamic tags carry a trailing "*". Chrome web
-- apps are not tagged, so they keep closing their window. The down/up split
-- mirrors Omarchy's clipboard bindings, which avoid send_shortcut leaving the
-- synthetic key stuck.
local browser_tags = { ["chromium-based-browser"] = true, ["firefox-based-browser"] = true }

local function active_window_is_browser()
  local window = hl.get_active_window()
  for _, tag in ipairs(window and window.tags or {}) do
    if browser_tags[tag:gsub("%*$", "")] then
      return true
    end
  end
  return false
end

hl.unbind("SUPER + W") -- was: Close window
o.bind("SUPER + W", "Close tab or window", function()
  if not active_window_is_browser() then
    hl.dispatch(hl.dsp.window.close())
    return
  end

  hl.dispatch(hl.dsp.send_key_state({ mods = "CTRL", key = "W", state = "down" }))
  hl.timer(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = "CTRL", key = "W", state = "up" }))
  end, { timeout = 50, type = "oneshot" })
end)
o.bind("SUPER + BACKSLASH", "Toggle window split", hl.dsp.layout("togglesplit"))

hl.unbind("SUPER + SLASH") -- was: Monitor scaling up
o.bind("SUPER + SLASH", "Show key bindings", "omarchy-menu-keybindings")

-- Application bindings that differ from the Omarchy defaults.
o.bind("SUPER + SHIFT + T", "Terminal", { omarchy = "terminal" })

hl.unbind("SUPER + SHIFT + S") -- was: Google Maps
o.bind("SUPER + SHIFT + S", "Browser", { omarchy = "browser" })

hl.unbind("SUPER + SHIFT + W") -- was: Omawrite
o.bind("SUPER + SHIFT + W", "Typora", { launch = "typora --enable-wayland-ime" })

-- Use Omasnap for the stock Print key and an alternate screenshot shortcut.
-- code:13 is the "4" key.
hl.unbind("PRINT") -- was: Omarchy screenshot
o.bind("PRINT", "Screenshot", "omasnap")
o.bind("ALT + SHIFT + code:13", "Screenshot", "omasnap")
o.bind("SUPER + SHIFT + CTRL + code:13", "Screenshot to clipboard", "omasnap --copy")

-- Keep Omasnap's layer-shell overlay instant and free of compositor animations.
hl.layer_rule({
  match = { namespace = "^omasnap$" },
  no_anim = true,
  animation = "none",
})

-- Manual touchpad toggle (automatic palm rejection lives in input.lua).
o.bind_toggle("SUPER + ALT + M", "Toggle touchpad", "touchpad")
