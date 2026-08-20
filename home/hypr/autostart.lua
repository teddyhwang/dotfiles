-- Extra autostart processes and the window rules that place them.

-- Palm rejection: touchpad off in terminals, on in browsers.
o.exec_on_start(os.getenv("HOME") .. "/.local/bin/trackpad-auto-toggle")

-- Name Herdr tabs after the agent's topic instead of leaving them numbered.
-- Idles until a Herdr server exists, so starting it at login is free.
o.exec_on_start(os.getenv("HOME") .. "/.local/bin/herdr-tab-autoname")

o.launch_on_start("google-chrome-stable")
o.launch_on_start("xdg-terminal-exec")
o.launch_on_start("google-chrome-stable --app=https://discord.com/channels/@me")
o.launch_on_start("google-chrome-stable --app=https://mail.google.com")
o.launch_on_start("google-chrome-stable --app=https://calendar.google.com")

-- Pin each of the above to its workspace.
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
o.window("^google-chrome$", { workspace = "1" })

-- Match whichever terminal is in use rather than pinning one.
o.window("^(com\\.mitchellh\\.ghostty|Alacritty|foot|kitty)$", { workspace = "2" })

o.window("^chrome-discord\\.com__channels_@me-Default$", { workspace = "3" })
o.window("^chrome-mail\\.google\\.com__-Default$", { workspace = "4" })
o.window("^chrome-calendar\\.google\\.com__-Default$", { workspace = "5" })
