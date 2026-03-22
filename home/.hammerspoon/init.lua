require("hs.ipc")

-- Move apps to screen 2 and reevaluate Amethyst after display changes (including display wake)

local apps = { "Messages", "Discord", "Ghostty" }

function MoveAppsToScreen2()
	local screens = hs.screen.allScreens()
	if #screens < 2 then
		hs.alert.show("Only one screen detected")
		return
	end

	local targetScreen = screens[2]

	for _, appName in ipairs(apps) do
		local app = hs.application.find(appName)
		if app then
			local windows = app:allWindows()
			for _, win in ipairs(windows) do
				if appName == "Messages" then
					local frame = win:frame()
					win:moveToScreen(targetScreen, false, false, 0)
					local movedFrame = win:frame()
					movedFrame.w = frame.w
					movedFrame.h = frame.h
					win:setFrame(movedFrame)
				else
					win:moveToScreen(targetScreen, false, false, 0)
				end
			end
		end
	end

	-- Force Amethyst to reevaluate windows (Option+Shift+Z)
	hs.eventtap.keyStroke({ "alt", "shift" }, "z")
end

local debounceTimer = nil

local function debouncedMove()
	if debounceTimer then
		debounceTimer:stop()
	end
	debounceTimer = hs.timer.doAfter(1, MoveAppsToScreen2)
end

local screenWatcher = hs.screen.watcher.new(debouncedMove)
screenWatcher:start()

-- Also trigger on display wake (e.g. coming back from display sleep or KVM switch)
local caffeinateWatcher = hs.caffeinate.watcher.new(function(event)
	if event == hs.caffeinate.watcher.screensDidWake or event == hs.caffeinate.watcher.systemDidWake then
		-- Screens need extra time to be fully ready after wake
		hs.timer.doAfter(3, debouncedMove)
	end
end)
caffeinateWatcher:start()

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

hs.alert.show("Hammerspoon loaded")
