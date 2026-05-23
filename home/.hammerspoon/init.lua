require("hs.ipc")

hs.allowAppleScript(true)

-- Move apps to screen 2 and reevaluate Amethyst after display changes (including display wake)

local screen2Apps = { "Discord", "Tico Dashboard", "Spotify" }
local screen1Apps = { "Ghostty" }

function MoveAppsToScreen2()
	local screens = hs.screen.allScreens()
	if #screens < 2 then
		return
	end

	local screen1 = screens[1]
	local screen2 = screens[2]

	local movedAny = false
	for _, appName in ipairs(screen2Apps) do
		local app = hs.application.find(appName)
		if app then
			for _, win in ipairs(app:allWindows()) do
				local ws = win:screen()
				if ws and ws:id() ~= screen2:id() then
					win:moveToScreen(screen2, false, false, 0)
					movedAny = true
				end
			end
		end
	end
	for _, appName in ipairs(screen1Apps) do
		local app = hs.application.find(appName)
		if app then
			for _, win in ipairs(app:allWindows()) do
				local ws = win:screen()
				if ws and ws:id() ~= screen1:id() then
					win:moveToScreen(screen1, false, false, 0)
					movedAny = true
				end
			end
		end
	end

	-- Delay Amethyst reevaluate so it doesn't undo the moves
	if movedAny then
		hs.timer.doAfter(2, function()
			hs.eventtap.keyStroke({ "alt", "shift" }, "z")
		end)
	end
end

-- Screen watcher for display reconfiguration (global to prevent GC)
ScreenWatcher = hs.screen.watcher.new(function()
	for _, delay in ipairs({ 1, 3, 7 }) do
		hs.timer.doAfter(delay, MoveAppsToScreen2)
	end
	StartWindowPolling()
end)
ScreenWatcher:start()

-- Caffeinate watcher for wake/unlock events (global to prevent GC)
CaffeinateWatcher = hs.caffeinate.watcher.new(function(event)
	if
		event == hs.caffeinate.watcher.screensDidWake
		or event == hs.caffeinate.watcher.systemDidWake
		or event == hs.caffeinate.watcher.screensDidUnlock
		or event == hs.caffeinate.watcher.sessionDidBecomeActive
	then
		for _, delay in ipairs({ 3, 7, 12, 20 }) do
			hs.timer.doAfter(delay, MoveAppsToScreen2)
		end
		StartWindowPolling()
	end
end)
CaffeinateWatcher:start()

-- Poll every 5 seconds for misplaced windows, but only for 60 seconds after wake/display change
WindowPollTimer = nil
WindowPollStopTimer = nil

function StartWindowPolling()
	if WindowPollStopTimer then
		WindowPollStopTimer:stop()
	end
	if not WindowPollTimer then
		WindowPollTimer = hs.timer.doEvery(5, function()
			local screens = hs.screen.allScreens()
			if #screens < 2 then
				return
			end

			local screen1 = screens[1]
			local screen2 = screens[2]
			for _, appName in ipairs(screen2Apps) do
				local app = hs.application.find(appName)
				if app then
					for _, win in ipairs(app:allWindows()) do
						if win:screen() and win:screen():id() ~= screen2:id() then
							MoveAppsToScreen2()
							return
						end
					end
				end
			end
			for _, appName in ipairs(screen1Apps) do
				local app = hs.application.find(appName)
				if app then
					for _, win in ipairs(app:allWindows()) do
						if win:screen() and win:screen():id() ~= screen1:id() then
							MoveAppsToScreen2()
							return
						end
					end
				end
			end
		end)
	end
	WindowPollStopTimer = hs.timer.doAfter(60, function()
		if WindowPollTimer then
			WindowPollTimer:stop()
			WindowPollTimer = nil
		end
	end)
end

hs.hotkey.bind({ "cmd", "shift" }, "W", MoveAppsToScreen2)

-- Workaround for Wave Link 3.1.x bug: app periodically re-activates itself to foreground.
-- Auto-hide it whenever it activates, unless the user just launched/clicked it.
WaveLinkUserActivatedAt = 0

WaveLinkWatcher = hs.application.watcher.new(function(appName, eventType, app)
	if appName ~= "Wave Link" and appName ~= "Elgato Wave Link" then
		return
	end
	if eventType == hs.application.watcher.activated then
		-- If user activated it within the last 5s, leave it alone
		if hs.timer.secondsSinceEpoch() - WaveLinkUserActivatedAt < 5 then
			return
		end
		hs.timer.doAfter(0.1, function()
			if app and app:isFrontmost() then
				app:hide()
			end
		end)
	end
end)
WaveLinkWatcher:start()

-- Hotkey to actually bring Wave Link forward when you want it (cmd+shift+L)
hs.hotkey.bind({ "cmd", "shift" }, "L", function()
	WaveLinkUserActivatedAt = hs.timer.secondsSinceEpoch()
	hs.application.launchOrFocus("Elgato Wave Link")
end)

hs.alert.show("Hammerspoon loaded")
