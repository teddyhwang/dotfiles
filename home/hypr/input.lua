-- Personal input overrides. Only the values that differ from Omarchy's
-- defaults live here; see $OMARCHY_PATH/default/hypr/input.lua for the rest.
-- Omarchy already sets kb_layout=us, kb_options=compose:caps,...,
-- repeat_rate=40, numlock_by_default=true and touchpad.clickfinger_behavior,
-- and it ships the terminal scroll_touchpad rules.
hl.config({
  input = {
    -- Faster than the 250ms default.
    repeat_delay = 200,

    -- Bump trackpad/mouse sensitivity off the 0 default.
    sensitivity = 0.35,

    touchpad = {
      -- Much slower than the 0.4 default.
      scroll_factor = 0.1,
    },
  },
})

-- No scroll_factor rule for "unknown-device": WayVNC's virtual pointer and
-- Deskflow's libei pointer share that name, and the old 0.05 Deskflow rule made
-- VNC scrolling 20x slower. Both now use the default 1.0.
