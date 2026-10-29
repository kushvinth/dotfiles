-- Pause music while the built-in mic records (FreeFlow's F5 / Left Option),
-- unless audio goes to Bluetooth; resume afterwards if we paused it.
local mc = "/opt/homebrew/bin/media-control"
local mic = hs.audiodevice.findInputByName("MacBook Pro Microphone")
local paused, querying = false, false

if mic then
	mic:watcherCallback(function(_, event)
		if event ~= "gone" then
			return
		end -- "gone": the mic started or stopped running
		if mic:inUse() then
			local out = hs.audiodevice.defaultOutputDevice()
			if paused or querying or (out and out:transportType() == "Bluetooth") then
				return
			end
			-- async: hs.execute would block the main thread (and readonly.lua's tap) per event;
			-- `querying` folds the duplicate "gone" events one mic start delivers
			querying = true
			local t = hs.task.new(mc, function(_, stdout)
				querying = false
				local ok, np = pcall(hs.json.decode, stdout or "")
				if ok and type(np) == "table" and np.playing then
					hs.task.new(mc, nil, { "pause" }):start()
					paused = true
				end
			end, { "get" })
			if not (t and t:start()) then
				querying = false
			end
		elseif paused then
			hs.task.new(mc, nil, { "play" }):start()
			paused = false
		end
	end)
	mic:watcherStart()
end

return mic
