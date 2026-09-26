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

-- Deskflow's libei pointer emits discrete wheel ticks, so scale them at the
-- compositor rather than with Deskflow's ineffective client scroll setting.
hl.device({ name = "unknown-device", scroll_factor = 0.05 })
