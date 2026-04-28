-------------------------------------------------------------------------------------------------------------------------------

local API = {
	player = {},
	game   = {},
	lobby  = {},
	run    = {},
}

-------------------------------------------------------------------------------------------------------------------------------

-- maid
local Tisha = loadstring(game:HttpGet("https://raw.githubusercontent.com/did-i-leave-the-oven-on/Tisha/refs/heads/main/Tisha.lua"))()
local runTasks = Tisha.new()
local globalTasks = Tisha.new()

-------------------------------------------------------------------------------------------------------------------------------

-- services
local getmmfromerr = function(userdata, f, test) local ret = nil xpcall(f, function() ret = debug.info(2, "f") end, userdata, nil, 0) if (type(ret) ~= "function") or not test(ret) then return f end return ret end
local randstring = function() local s = "" for i = 1, math.random(8, 15) do if math.random(2) == 2 then s = s .. string.char(math.random(65, 90)) else s = s .. string.char(math.random(97, 122)) end end return s end

local getins = getmmfromerr(game, function(a,b) return a[b] end, function(f) local a = Instance.new("Folder") local b = randstring() a.Name = b return f(a, "Name") == b end)
local FindFirstChildOfClass = getins(game, "FindFirstChildOfClass")

local ws = FindFirstChildOfClass(game, "Workspace")
local plrs = FindFirstChildOfClass(game, "Players")

-------------------------------------------------------------------------------------------------------------------------------

-- player
API.player.plr = getins(plrs, "LocalPlayer")
API.player.user = getins(API.player.plr, "Name")
API.player.displayName = getins(API.player.plr, "DisplayName")
API.player.plrid = getins(API.player.plr, "UserId")
API.player.cam = ws.CurrentCamera
API.player.mouse = getins(API.player.plr, "GetMouse")(API.player.plr)
API.player.plrGui = API.player.plr:WaitForChild("PlayerGui")
API.player.char = API.player.plr.Character or API.player.plr.CharacterAdded:Wait()
API.player.hum = API.player.char:WaitForChild("Humanoid")
API.player.root = API.player.char:WaitForChild("HumanoidRootPart")
API.player.backpack = API.player.plr:WaitForChild("Backpack")
API.player.plrStats = nil

local function updcharrefs(char)
	if not char then return end
    
	API.player.char = char
	API.player.plrStats = char:WaitForChild("Stats", 5) or API.player.plrStats
	API.player.backpack = API.player.plr:WaitForChild("Backpack", 5) or API.player.backpack
	API.player.hum = char:WaitForChild("Humanoid", 5) or API.player.hum
	API.player.root = char:WaitForChild("HumanoidRootPart", 5) or API.player.root
end

updcharrefs(API.player.char)

globalTasks:give(API.player.plr.CharacterAdded:Connect(updcharrefs), "charAdded")

globalTasks:give(ws:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	API.player.cam = ws.CurrentCamera
end), "cameraChanged")

-------------------------------------------------------------------------------------------------------------------------------

-- game
local placeId = getins(game, "PlaceId")
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

-- keep character refs up to datew
globalTasks:spawn(function()
	if API.game.plrFolder:FindFirstChild(API.player.user) then
		updcharrefs(API.player.char)
	end
end)

globalTasks:give(API.game.plrFolder.ChildAdded:Connect(function(child)
	if child.Name == API.player.user then
		updcharrefs(API.player.char)
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
function API.run.getRoom() -- checks if there is a model child in the roomFolder; if there is, assign currentRoom and returns it
	if API.run.currentRoom and API.run.currentRoom.Parent then
		return API.run.currentRoom
	end
    
	API.run.currentRoom = API.run.roomFolder:FindFirstChildWhichIsA("Model")
	return API.run.currentRoom
end

function API.run.roomComplete() -- returns true if the room has all its components
	local r = API.run.currentRoom
    
	return r:FindFirstChild("FreeArea") ~= nil and r:FindFirstChild("Monsters") ~= nil and r:FindFirstChild("Items") ~= nil and r:FindFirstChild("Generators") ~= nil
end

function API.run.exists(plr) -- returns true if the target player (defaults to local player) is in the plrFolder folder
	return API.game.plrFolder:FindFirstChild(plr and plr.Name or API.player.user) ~= nil
end

function API.run.floorLoaded() -- returns true if the floor has completely loaded
	return API.run.getGameStats().message:find("Doors open") ~= nil
end

function API.run.floorUnloading() -- returns true if the room is being unloaded
	local stats = API.run.getGameStats()
    
	return stats and stats.message:find("Quickly") ~= nil and not API.run.elevator:FindFirstChild("Opened").Value
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

-------------------------------------------------------------------------------------------------------------------------------

return API

-------------------------------------------------------------------------------------------------------------------------------
