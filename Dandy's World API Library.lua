-------------------------------------------------------------------------------------------------------------------------------

local API = {
	funcs = {},

	player = {},
	game = {},
	lobby = {},
	run = {},
}

-------------------------------------------------------------------------------------------------------------------------------

-- maid
local Tisha = loadstring(game:HttpGet("https://raw.githubusercontent.com/did-i-leave-the-oven-on/Tisha/refs/heads/main/Tisha.lua"))()
local runTasks = Tisha.new()
local globalTasks = Tisha.new()

-------------------------------------------------------------------------------------------------------------------------------

-- services
local getMetaMethodFromErr = function(userdata, f, test) local ret = nil xpcall(f, function() ret = debug.info(2, "f") end, userdata, nil, 0) if (type(ret) ~= "function") or not test(ret) then return f end return ret end
local randString = function() local s = "" for i = 1, math.random(8, 15) do if math.random(2) == 2 then s = s .. string.char(math.random(65, 90)) else s = s .. string.char(math.random(97, 122)) end end return s end

local getIns = getMetaMethodFromErr(game, function(a,b) return a[b] end, function(f) local a = Instance.new("Folder") local b = randString() a.Name = b return f(a, "Name") == b end)
local FindFirstChildOfClass = getIns(game, "FindFirstChildOfClass")

local ws = FindFirstChildOfClass(game, "Workspace")
local plrs = FindFirstChildOfClass(game, "Players")
local rst = FindFirstChildOfClass(game, "ReplicatedStorage")

-------------------------------------------------------------------------------------------------------------------------------

-- player
API.player.plr = getIns(plrs, "LocalPlayer")
API.player.plrid = getIns(API.player.plr, "UserId")
API.player.plrStats = nil

API.player.user = getIns(API.player.plr, "Name")
API.player.displayName = getIns(API.player.plr, "DisplayName")

API.player.cam = ws.CurrentCamera
API.player.mouse = getIns(API.player.plr, "GetMouse")(API.player.plr)
API.player.plrGui = API.player.plr:WaitForChild("PlayerGui")

API.player.char = API.player.plr.Character or API.player.plr.CharacterAdded:Wait()
API.player.hum = API.player.char:WaitForChild("Humanoid")
API.player.root = API.player.char:WaitForChild("HumanoidRootPart")
API.player.backpack = API.player.plr:WaitForChild("Backpack")

function API.funcs.updateCharacterRefs(char)
	if not char then return end

	API.player.char = char
	API.player.plrStats = char:WaitForChild("Stats", 5) or API.player.plrStats
	API.player.backpack = API.player.plr:WaitForChild("Backpack", 5) or API.player.backpack
	API.player.hum = char:WaitForChild("Humanoid", 5) or API.player.hum
	API.player.root = char:WaitForChild("HumanoidRootPart", 5) or API.player.root
end

API.funcs.updateCharacterRefs(API.player.char)

globalTasks:give(API.player.plr.CharacterAdded:Connect(function()
	API.funcs.updateCharacterRefs()
end), "charAdded")

globalTasks:give(ws:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	API.player.cam = ws.CurrentCamera
end), "cameraChanged")

-------------------------------------------------------------------------------------------------------------------------------

-- game
local placeId = getIns(game, "PlaceId")
API.lobby.placeId = 16116270224
API.run.placeId = 16552821455

API.lobby.detected = placeId == API.lobby.placeId
API.run.detected = placeId == API.run.placeId

API.game.plrFolder = ws:WaitForChild(API.run.detected and "InGamePlayers" or "Players")

API.run.roomFolder = nil -- ws.CurrentRoom
API.run.elevator = nil -- ws.Elevators.Elevator
API.run.info = nil -- ws.Info
API.run.currentRoom = nil -- the model inside the roomFolder
API.run.freeArea = nil -- currentRoom.FreeArea
API.run.fakeElevator = nil -- currentRoom.FreeArea.FakeElevator
API.run.twisteds = nil -- currentRoom.Monsters
API.run.items = nil -- currentRoom.Items
API.run.machines = nil -- currentRoom.Generators
API.run.puddles = nil -- currentRoom.Puddles (ichor leak floors only)

-------------------------------------------------------------------------------------------------------------------------------

-- keep character refs up to date
globalTasks:spawn(function()
	if API.game.plrFolder:FindFirstChild(API.player.user) then
		API.funcs.updateCharacterRefs(API.player.char)
	end
end)

globalTasks:give(API.game.plrFolder.ChildAdded:Connect(function(child)
	if child.Name == API.player.user then
		API.funcs.updateCharacterRefs(API.player.char)
	end
end), "playerFolderAdded")

-------------------------------------------------------------------------------------------------------------------------------

-- room refs tracker
if API.run.detected then
	runTasks:spawn(function()
		API.run.elevator = ws:WaitForChild("Elevators"):WaitForChild("Elevator")
		API.run.roomFolder = ws:WaitForChild("CurrentRoom")

		runTasks:give(API.run.roomFolder.ChildAdded:Connect(updateReferences), "roomFolderAdded")
		runTasks:give(API.run.roomFolder.ChildRemoved:Connect(updateReferences), "roomFolderRemoved")

		updateReferences()
	end)

	function updateReferences()
		runTasks:remove("debounce")

		runTasks:give(task.delay(0.2, function()
			API.run.info = ws:FindFirstChild("Info")

			if API.run.floorUnloading() then return end

			local newRoom = API.run.getRoom()
			if not newRoom then return end

			API.run.currentRoom = newRoom
			API.run.freeArea = newRoom:WaitForChild("FreeArea", 10)
			API.run.fakeElevator = API.run.freeArea and API.run.freeArea:WaitForChild("FakeElevator", 10)
			API.run.twisteds = newRoom:WaitForChild("Monsters", 10)
			API.run.items = newRoom:WaitForChild("Items", 10)
			API.run.machines = newRoom:WaitForChild("Generators", 10)
			API.run.puddles = newRoom:WaitForChild("Puddles", 5)

			runTasks:remove("roomChildAdded")
			runTasks:remove("roomChildRemoved")
			runTasks:give(newRoom.ChildAdded:Connect(updateReferences),   "roomChildAdded")
			runTasks:give(newRoom.ChildRemoved:Connect(updateReferences), "roomChildRemoved")
		end), "debounce")
	end
end

-------------------------------------------------------------------------------------------------------------------------------

-- helpers
function API.run.getRoom() -- checks if there is a model child in the roomFolder. if there is, it assigns currentRoom and returns it
	if API.run.currentRoom and API.run.currentRoom.Parent then
		return API.run.currentRoom
	end

	API.run.currentRoom = API.run.roomFolder:FindFirstChildWhichIsA("Model")
	return API.run.currentRoom
end

function API.run.roomComplete() -- returns true if the currentRoom has all its components
	local r = API.run.currentRoom

	return r:FindFirstChild("FreeArea") and r:FindFirstChild("Monsters") and r:FindFirstChild("Items") and r:FindFirstChild("Generators")
end

function API.run.exists(plr) -- returns true if the target player (defaults to local player) is in the plrFolder folder
	return API.game.plrFolder:FindFirstChild(plr and plr.Name or API.player.user)
end

function API.run.floorLoaded() -- returns true if the floor has completely loaded
	return API.run.getGameStats().message:find("Doors open")
end

function API.run.floorUnloading() -- returns true if the floor is being unloaded
	local stats = API.run.getGameStats()

	return stats and stats.message:find("Quickly") and not API.run.elevator:FindFirstChild("Opened").Value
end

function API.run.nearObstacle(tendrilExists, posCheck) -- returns true if the player is near an obstacle. if tendrilExists is true, it will return true if Sprout's Tendril exists. posCheck can be an optional Vector3 to test against instead of the player's root position
	if not API.run.currentRoom then return false end
	local origin = posCheck or API.player.root.Position

	if API.run.freeArea then
		for _, obj in ipairs(API.run.freeArea:GetChildren()) do
			if obj.Name:find("Tendril") then
				local root = obj:FindFirstChild("HumanoidRootPart")

				if root then
					local threshold = tendrilExists and 9999 or 23
					if (root.Position - origin).Magnitude <= threshold then
						return true, "Sprout"
					end
				end
			end
		end
	end

	for _, obj in ipairs(API.run.currentRoom:GetChildren()) do
		if obj.Name:find("BlotHand") then
			local model = obj:FindFirstChildWhichIsA("Model")
			local root  = model and model:FindFirstChild("RootPart")

			if root and (root.Position - origin).Magnitude <= 20 then
				return true, "Blot"
			end
		end
	end

	return false, nil
end

function API.run.getStats(type, obj, stat) -- collects and returns a table of stats for the given object type. if stat is provided, it returns only that field's value instead of the full table
	if type ~= "floor" then
		if not obj then return end
		if not obj:IsA("Model") then return end
	end

	local result

	if type == "floor" then
		if not API.run.currentRoom then return end
		if API.run.floorUnloading() then return end

		local twistedsonfloor = {}
		for _, model in ipairs(API.run.twisteds:GetChildren()) do
			if model:IsA("Model") then
				table.insert(twistedsonfloor, model)
			end
		end

		local itemsonfloor = {}
		for _, model in ipairs(API.run.items:GetChildren()) do
			if model:IsA("Model") then
				table.insert(itemsonfloor, model)
			end
		end

		result = {
			floorname = API.run.currentRoom.Name,
			twistedsonfloor = twistedsonfloor,
			itemsonfloor = itemsonfloor,
			hasdialoguetriggers = API.run.currentRoom:GetAttribute("HasDialogueTriggers"),
		}

	elseif type == "item" then
		if not API.run.items then return end
		if API.run.floorUnloading() then return end

		local prompt = obj:FindFirstChild("Prompt")
		local prox = prompt and prompt:FindFirstChildOfClass("ProximityPrompt")

		local research
		if obj.Name == "ResearchCapsule" then
			research = prompt and prompt:FindFirstChild("Monster").Value or 0
		end

		result = {
			prox = prox,
			research = research,
		}

	elseif type == "machine" then
		if not API.run.machines then return end
		if API.run.floorunloading() then return end

		local dualmachine = obj:GetAttribute("IsDualGen")

		local stats = obj:FindFirstChild("Stats") or nil
		local pos, pos2

		if obj:FindFirstChild("TeleportPositions") then
			if obj:FindFirstChild("TeleportPositions"):FindFirstChild("TeleportPosition") then
				pos = obj:FindFirstChild("TeleportPositions"):FindFirstChild("TeleportPosition").CFrame * CFrame.new(0, 2.3, 0)

				if dualmachine then
					pos2 = obj:FindFirstChild("TeleportPositions_Mirror"):FindFirstChild("TeleportPosition2").CFrame * CFrame.new(0, 2.3, 0)
				end
			else
				pos = CFrame.new(0, 0, 0)
				pos2 = CFrame.new(0, 0, 0)
			end
		else
			pos = CFrame.new(0, 0, 0)
			pos2 = CFrame.new(0, 0, 0)
		end

		local prox, prox2
		if obj:FindFirstChild("Prompt") then
			prox = obj:FindFirstChild("Prompt"):FindFirstChild("ProximityPrompt", true)
		elseif dualmachine then
			prox2 = obj:WaitForChild("Prompt2"):FindFirstChild("ProximityPrompt", true) or nil
		end

		local active = stats:FindFirstChild("ActivePlayer").Value
		local active2 = dualmachine and stats:WaitForChild("ActivePlayer2").Value or nil
		local completed = stats:FindFirstChild("Completed").Value
		local possessed = stats:FindFirstChild("Connie").Value
		local amount = stats:FindFirstChild("CurrentAmount").Value
		local required = stats:FindFirstChild("RequiredAmount").Value

		local machtype = obj:GetAttribute("MinigameType")
		if machtype == "MovementTreadmill" then 
			machtype = "treadmill"
			pos = obj:FindFirstChild("TeleportPositions"):FindFirstChild("TreadmillTeleportPosition").CFrame * CFrame.new(0, 2.3, 0)

			if dualmachine then
				pos2 = obj:FindFirstChild("TeleportPositions_Mirror"):FindFirstChild("TreadmillTeleportPosition").CFrame * CFrame.new(0, 2.3, 0)
			end
		elseif machtype == "Circle" then 
			machtype = "circle"
		else
			machtype = "normal"
		end

		local machtype2 = obj:GetAttribute("Prompt2MinigameType") or "none"
		if machtype2 ~= "none" then
			if machtype2 == "MovementTreadmill" then 
				machtype2 = "treadmill"
			elseif machtype2 == "Circle" then 
				machtype2 = "circle"
			elseif machtype2 == "SwimmyBarnaby" then 
				machtype2 = "arcade"
			else
				machtype2 = "normal"
			end
		end

		result = {
			pos = pos, 
			pos2 = pos2,
			prox = prox,
			prox2 = prox2,
			active = active, 
			active2 = active2, 
			completed = completed, 
			possessed = possessed, 
			amount = amount, 
			required = required,
			dualmachine = dualmachine,
			machtype = machtype,
			machtype2 = machtype2
		}

	elseif type == "twisted" then
		if not API.run.twisteds or not API.run.currentRoom then return end

		local tname = obj.Name
		local troot = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")

		local hearingrad, intrestrad, hitboxrad, visionrad, intresttime, LoS, hitcooldown = 0, 0, 0, 0, 0, 0, 0
		local chaser = not tname:find("Connie") and not tname:find("Blot") and obj:FindFirstChild("Chaser")
		if chaser then
			local function cv(n) return chaser:FindFirstChild(n).Value end
			hearingrad = cv("HearingRadius")
			intrestrad = cv("InstantRadius")
			hitboxrad = cv("HitboxRadius")
			visionrad = cv("VisionRadius")
			intresttime = cv("InterestTime")
			LoS = cv("LineOfSight")
			hitcooldown = cv("HitCooldown")
		end

		local chasingValue = not tname:find("Connie") and not tname:find("Blot") and obj:FindFirstChild("ChasingValue")
		local chasing = chasingValue and chasingValue.Value or nil
		local ischasing = chasing ~= nil

		local hasability = obj:FindFirstChild("Grabbing")
		local usingability = hasability and hasability.Value

		local alerted = obj:GetAttribute("Alerted")

		local plrresearch = rst:FindFirstChild("PlayerData") and rst.PlayerData:FindFirstChild(API.player.plrid) and rst.PlayerData[API.player.plrid]:FindFirstChild("Research")
		local tr = plrresearch and plrresearch:FindFirstChild(tname)
		local research = tr and tr.Value or 0

		result = {
			name = tname,
			troot = troot,
			alerted = alerted,
			research = research,
			hearingrad = hearingrad,
			intrestrad = intrestrad,
			hitboxrad = hitboxrad,
			visionrad = visionrad,
			intresttime = intresttime,
			LoS = LoS,
			hitcooldown = hitcooldown,
			chasing = chasing,
			ischasing = ischasing,
			hasability = hasability,
			usingability = usingability,
		}

	elseif type == "player" then
		local inserver = plrs:FindFirstChild(obj.Name)

		if not inserver then return end

		local ins = inserver and plrs:FindFirstChild(obj.Name)
		local currenttoon = obj:GetAttribute("ToonName")

		if not API.run.detected then return {ins = ins, currenttoon = currenttoon} end

		local icon = obj:FindFirstChild("Config") and obj:FindFirstChild("Config"):FindFirstChild("Icon").Texture or "rbxassetid://0"
		local runstats = API.run.info:FindFirstChild("PlayerStats"):FindFirstChild(ins.Name)

		local capsulespickedup, itemspickedup, machinescompleted, ichorearned, twistedsencountered, tapescollected
		if runstats then
			capsulespickedup = runstats:FindFirstChild("Capsules").Value
			itemspickedup = runstats:FindFirstChild("Items").Value
			machinescompleted = runstats:FindFirstChild("Generators").Value
			ichorearned = runstats:FindFirstChild("Ichor").Value
			twistedsencountered = runstats:FindFirstChild("Monsters").Value
			tapescollected = runstats:FindFirstChild("SurvivalPoints").Value
		end

		local toonpicked = ins:GetAttribute("SelectedCharacter")
		local dead = inserver and not ws:FindFirstChild("InGamePlayers"):FindFirstChild(ins.Name)
		local left = inserver == false

		local function fetchitem(slot)
			local ins = obj:FindFirstChild("Inventory") and obj:FindFirstChild("Inventory"):FindFirstChild("Slot" .. slot)
			if not ins then return "None" end
			if slot == 4 then if not ins then return "None" end end
			return ins.Value
		end

		local function fetchtrinket(slot)
			return ins:GetAttribute("EquippedTrinket" .. slot) or "None"
		end

		local slot1, slot2, slot3, slot4 = fetchitem(1), fetchitem(2), fetchitem(3), fetchitem(4)
		local inventoryfull = slot1 ~= "None" and slot2 ~= "None" and slot3 ~= "None" and (slot4 and slot4 ~= "None")
		local trinket1, trinket2 = fetchtrinket(1), fetchtrinket(2)

		local extracting = obj:FindFirstChild("Decoding").Value
		local currentstealth = ins:GetAttribute("Stealth") or 0
		local twistedschasing = ins:GetAttribute("ChaseCount") or 0

		local abilitycooldown, currentabilitycooldown

		if obj:FindFirstChild("Abilities") then
			for _, ability in pairs(obj:FindFirstChild("Abilities"):GetChildren()) do
				if ability:FindFirstChild("Cooldown") then
					abilitycooldown = ability:FindFirstChild("Cooldown").Value
					currentabilitycooldown = ability:FindFirstChild("CurrentCooldown").Value
				end
			end
		end

		result = {
			currentstealth = currentstealth, 
			twistedschasing = twistedschasing, 
			currenttoon = currenttoon, 
			inserver = inserver, 
			ins = ins, 
			dead = dead, 
			left = left, 
			capsulespickedup = capsulespickedup or 0, 
			itemspickedup = itemspickedup or 0, 
			machinescompleted = machinescompleted or 0, 
			ichorearned = ichorearned or 0, 
			twistedsencountered = twistedsencountered or 0, 
			tapescollected = tapescollected or 0, 
			toonpicked = toonpicked, 
			slot1 = slot1, 
			slot2 = slot2, 
			slot3 = slot3, 
			slot4 = slot4, 
			trinket1 = trinket1, 
			trinket2 = trinket2, 
			extracting = extracting, 
			icon = icon, 
			abilitycooldown = abilitycooldown, 
			currentabilitycooldown = currentabilitycooldown
		}
	end

	if stat ~= nil then return result[stat] end
	return result
end

function API.run.getGameStats() -- returns a table of all the current game stats
	if not API.run.info then return nil end

	local function val(name)
		return API.run.info:FindFirstChild(name).Value
	end

	return {
		gamestarted = val("GameStarted"),
		cardvoting = val("CardVoting"),
		dandyselling = val("DandyStoreOpen"),
		currentfloor = val("Floor"),
		flooractive = val("FloorActive"),
		panicmode = val("Panic"),
		machscompleted = val("GeneratorsCompleted"),
		machsrequired = val("RequiredGenerators"),
		blackout = val("BlackOut"),
		playersalive = val("ActivePlayers"),
		boughtnothingfor = API.run.info:FindFirstChild("DandyTracker"):FindFirstChild("NoBuy").Value,
		message = val("Message"),
	}
end

function API.mapname(name) -- used for name mapping
	local itemnamemap = {
		["Air Horn"] = "AirHorn",
		["Bandage"] = "Bandage",
		["Bonbon"] = "BonBon",
		["Bottle o' Pop"] = "PopBottle",
		["Box o' Chocolates"] = "ChocolateBox",
		["Chocolate"] = "Chocolate",
		["Christmas Cookie"] = "ChristmasCookie",
		["Easter Egg"] = "DandyEasterEggs",
		["Eject Button"] = "EjectButton",
		["Extraction Speed Candy"] = "ExtractionSpeedCandy",
		["Event Currency"] = "HolidayCollectibleItem",
		["Fake Capsule"] = "FakeCapsule",
		["Gumballs"] = "Gumball",
		["Health Kit"] = "HealthKit",
		["Instructions"] = "Instructions",
		["Jawbreaker"] = "Jawbreaker",
		["Jumper Cable"] = "JumperCable",
		["Pop"] = "Pop", 
		["Protein Bar"] = "ProteinBar",
		["Research Capsule"] = "ResearchCapsule",
		["Skill Check Candy"] = "SkillCheckCandy",
		["Smoke Bomb"] = "SmokeBomb",
		["Speed Candy"] = "SpeedCandy",
		["Stamina Candy"] = "StaminaCandy",
		["Stealth Candy"] = "StealthCandy",
		["Stopwatch"] = "Stopwatch",
		["Tape"] = "Tape",
		["Valve"] = "Valve"
	}

	if name:find("Monster") then
		name = string.gsub(name, "Monster", "")

		if name == "RazzleDazzle" then
			name = "Razzle & Dazzle"
		elseif name == "Blott" then
			name = "Blot"
		end

		return "Twisted " .. name
	end

	if name == "RazzleDazzle" then
		return "Razzle & Dazzle"
	elseif name == "Blott" then
		return "Blot"
	end

	return itemnamemap[name] or name
end

-------------------------------------------------------------------------------------------------------------------------------

return API

-------------------------------------------------------------------------------------------------------------------------------
