-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1
local laptop_scale = 2
local dp3_mode = "modeline 241.50 2560 2608 2640 2720 1440 1443 1448 1481 +hsync -vsync"
local clamshell = o.shell_succeeds("omarchy hw clamshell")

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- DP-3 does not expose an EDID, so provide its native 2560x1440 mode explicitly.
if clamshell then
  -- With the lid closed, render natively for the external panel. Omarchy's
  -- clamshell toggle disables eDP-1 after this rule makes DP-3 the source.
  hl.monitor({ output = "DP-3", mode = dp3_mode, position = "0x0", scale = 1 })
else
  -- With the lid open, render at the laptop panel's native resolution and use
  -- it as the mirror source. This keeps eDP-1 sharp at 3072x1920 with 2x scale.
  hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = laptop_scale })
  hl.monitor({ output = "DP-3", mode = dp3_mode, position = "0x0", scale = 1, mirror = "eDP-1" })
end

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
