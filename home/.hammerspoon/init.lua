require("hs.ipc")

hs.allowAppleScript(true)

-- Move apps to screen 2 and reevaluate Amethyst after display changes (including display wake)

local apps = { "Discord", "Ghostty", "Spotify" }

function MoveAppsToScreen2()
	local screens = hs.screen.allScreens()
	if #screens < 2 then
		return
	end

	local targetScreen = screens[2]

	local movedAny = false
	for _, appName in ipairs(apps) do
		local app = hs.application.find(appName)
		if app then
			for _, win in ipairs(app:allWindows()) do
				local ws = win:screen()
				if ws and ws:id() ~= targetScreen:id() then
					win:moveToScreen(targetScreen, false, false, 0)
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
	end
end)
CaffeinateWatcher:start()

-- Poll every 5 seconds for misplaced windows as a fallback (global to prevent GC)
WindowPollTimer = hs.timer.doEvery(5, function()
	local screens = hs.screen.allScreens()
	if #screens < 2 then
		return
	end

	local targetScreen = screens[2]
	for _, appName in ipairs(apps) do
		local app = hs.application.find(appName)
		if app then
			for _, win in ipairs(app:allWindows()) do
				if win:screen() and win:screen():id() ~= targetScreen:id() then
					MoveAppsToScreen2()
					return
				end
			end
		end
	end
end)

-- Restart Elgato Wave Link and close its window
function RestartWaveLink()
	local app = hs.application.find("Wave Link")
	if app then
		app:kill()
	end

	hs.timer.doAfter(2, function()
		hs.application.open("Elgato Wave Link")

		-- Wait for it to launch, then close the window
		hs.timer.doAfter(3, function()
			local waveApp = hs.application.find("Wave Link")
			if waveApp then
				local windows = waveApp:allWindows()
				for _, win in ipairs(windows) do
					win:close()
				end
			end
		end)
	end)
end

hs.hotkey.bind({ "cmd", "shift" }, "W", MoveAppsToScreen2)

hs.alert.show("Hammerspoon loaded")
