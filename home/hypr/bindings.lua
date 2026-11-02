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

-- macOS-style Command shortcuts. These used to be keyd remaps, but keyd only
-- sees physical evdev keyboards. WayVNC (Screen Sharing's Command arrives as
-- Super through the macvnc keymap) and Deskflow type through virtual keyboards
-- that go straight to Hyprland, so they never got them. Hyprland binds see
-- every keyboard, physical or virtual.
--
-- Browser tags come from Omarchy's default/hypr/apps/browser.lua; dynamic tags
-- carry a trailing "*". Chrome web apps are not tagged, so they keep the
-- non-browser behavior.
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

-- Sends mods+key to the focused surface. The down/up split mirrors Omarchy's
-- clipboard bindings, which avoid send_shortcut leaving the synthetic key
-- stuck. A repeating bind fires again before the release timer runs, so the
-- key stays down while the chord is held and the app repeats it as usual.
local held_shortcuts = {}

local function press_shortcut(mods, key)
  local id = mods .. " " .. key
  local state = held_shortcuts[id] or { generation = 0, down = false }
  held_shortcuts[id] = state
  state.generation = state.generation + 1
  local generation = state.generation

  if not state.down then
    state.down = true
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
  end

  hl.timer(function()
    if state.generation == generation then
      state.down = false
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end
  end, { timeout = 50, type = "oneshot" })
end

local function shortcut(mods, key)
  return function()
    press_shortcut(mods, key)
  end
end

local function dispatch(dispatcher)
  return function()
    hl.dispatch(dispatcher)
  end
end

-- In browsers, send mods+key. Elsewhere, call `otherwise`, which either runs
-- the old dispatcher or forwards the original chord unchanged.
local function browser_shortcut(mods, key, otherwise)
  return function()
    if active_window_is_browser() then
      press_shortcut(mods, key)
    else
      otherwise()
    end
  end
end

-- Global text editing: Cmd+A selects all, Cmd+arrows move by word.
o.bind("SUPER + A", "Select all", shortcut("CTRL", "A"))
for _, arrow in ipairs({ "LEFT", "RIGHT", "UP", "DOWN" }) do
  hl.unbind("SUPER + " .. arrow) -- was: Focus window (SUPER + H/J/K/L still do)
  o.bind("SUPER + " .. arrow, "Ctrl+" .. arrow:lower(), shortcut("CTRL", arrow), { repeating = true })
end

-- Browser tabs. Hyprland resolves bind keysyms without Shift, so these match
-- whether the keyboard reports the key as a bracket or a brace.
o.bind("SUPER + SHIFT + bracketleft", "Previous browser tab",
  browser_shortcut("CTRL SHIFT", "Tab", shortcut("SUPER SHIFT", "bracketleft")), { repeating = true })
o.bind("SUPER + SHIFT + bracketright", "Next browser tab",
  browser_shortcut("CTRL", "Tab", shortcut("SUPER SHIFT", "bracketright")), { repeating = true })

hl.unbind("SUPER + T") -- was: Toggle window floating/tiling
o.bind("SUPER + T", "New tab or toggle floating",
  browser_shortcut("CTRL", "T", dispatch(hl.dsp.window.float({ action = "toggle" }))))
o.bind("SUPER + R", "Reload browser tab", browser_shortcut("CTRL", "R", shortcut("SUPER", "R")))

-- SUPER + W closes the tab in full browsers and the window everywhere else.
hl.unbind("SUPER + W") -- was: Close window
o.bind("SUPER + W", "Close tab or window", browser_shortcut("CTRL", "W", dispatch(hl.dsp.window.close())))
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
