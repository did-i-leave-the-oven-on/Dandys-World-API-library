-------------------------------------------------------------------------------------------------------------------------------

-- load it
local API = loadstring(game:HttpGet("https://raw.githubusercontent.com/did-i-leave-the-oven-on/Dandys-World-API-library/refs/heads/main/Dandy's%20World%20API%20Library.lua"))()

-------------------------------------------------------------------------------------------------------------------------------

-- player check
print("hello " .. API.player.displayName .. " (@" .. API.player.user .. ")")

-------------------------------------------------------------------------------------------------------------------------------

-- checking if in a run or lobby
if API.run.detected then
	print("youre in run!")
elseif API.lobby.detected then
	print("you lobbiye.....")
end

-------------------------------------------------------------------------------------------------------------------------------

-- game checking loop example
task.spawn(function()
	while true do
		task.wait(1)

		if not API.run.detected then continue end
		if not API.run.currentRoom then continue end

		-- get floor stats
		local floorStats = API.run.getStats("floor")
		if floorStats then
			print("current room:", floorStats.floorname)
			print("Twisteds in room:", #floorStats.twistedsonfloor)
			print("items in room:", #floorStats.itemsonfloor)
		end

		-- check if room is complete
		if API.run.roomComplete() then
			print("room fully loaded")
		end

		-- check for Sprout's tendrils or Blot's hands
		local near, typeName = API.run.nearObstacle(true)
		if near then
			warn(typeName .. "'s gonna kill yer")
		end
	end
end)

-------------------------------------------------------------------------------------------------------------------------------

-- machine tracking
task.spawn(function()
	while true do
		task.wait(2)

		if not API.run.machines then continue end

		for _, machine in ipairs(API.run.machines:GetChildren()) do
			local stats = API.run.getStats("machine", machine)
			if stats then
				if not stats.completed and not stats.activeplayer then -- incomplete and unoccupied
					print("this machine isnt completed and is available")
				end
			end
		end
	end
end)

-------------------------------------------------------------------------------------------------------------------------------

-- tracking other players
task.spawn(function()
	while true do
		task.wait(3)

		for _, plrModel in ipairs(API.game.plrFolder:GetChildren()) do
			local stats = API.run.getStats("player", plrModel)

			if stats then
				print(plrModel.Name .. " is playing as " .. stats.currenttoon .. " and is currently " .. 
            (stats.dead and "dead") or "still alive and their inventory is " .. (stats.inventoryfull and "full") or "not full")
			end
		end
	end
end)

-------------------------------------------------------------------------------------------------------------------------------

-- checking game info
task.spawn(function()
	while true do
		task.wait(2)

		local gameStats = API.run.getGameStats()
		if gameStats then
			print("current floor: " .. gameStats.currentfloor)
			print("machines: " .. gameStats.machscompleted .. "/" .. gameStats.machsrequired)
			print("players alive: " .. gameStats.playersalive)

			if gameStats.panicmode then
				warn("run to the elevatgor fatty!!!!")
			end
		end
	end
end)

-------------------------------------------------------------------------------------------------------------------------------
