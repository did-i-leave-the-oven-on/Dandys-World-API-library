-------------------------------------------------------------------------------------------------------------------------------

local API = {
  player = {},
  game = {},

  lobby = {},
  run = {},
  roleplay = {} -- no
}

-------------------------------------------------------------------------------------------------------------------------------

local Tisha = loadstring(game:HttpGet("https://raw.githubusercontent.com/did-i-leave-the-oven-on/Tisha/refs/heads/main/Tisha.lua"))()
local runTasks = Tisha.new()
local globalTasks = Tisha.new()

-------------------------------------------------------------------------------------------------------------------------------

local getmmfromerr = function(userdata, f, test) local ret = nil xpcall(f, function() ret = debug.info(2, "f") end, userdata, nil, 0) if (type(ret) ~= "function") or not test(ret) then return f end return ret end
local randstring = function() local s = "" for i = 1, math.random(8, 15) do if math.random(2) == 2 then s = s .. string.char(math.random(65, 90)) else s = s .. string.char(math.random(97, 122)) end end return s end

local getins = getmmfromerr(game, function(a,b) return a[b] end, function(f) local a = Instance.new("Folder") local b = randstring() a.Name = b return f(a, "Name") == b end)
local FindFirstChildOfClass = getins(game, "FindFirstChildOfClass")

local ws = FindFirstChildOfClass(game, "Workspace")
local plrs = FindFirstChildOfClass(game, "Players")

-------------------------------------------------------------------------------------------------------------------------------

-- player character stuff
API.player.plr = getins(plrs, "LocalPlayer")
API.player.backpack = API.player.plr:WaitForChild("Backpack")
API.player.user = getins(API.player.plr, "Name")
API.player.displayName = getins(API.player.plr, "DisplayName")
API.player.plrid = getins(API.player.plr, "UserId")

API.player.char = API.player.plr.Character or API.player.plr.CharacterAdded:Wait()
API.player.hum = API.player.char:WaitForChild("Humanoid")
API.player.root = API.player.char:WaitForChild("HumanoidRootPart")

API.player.cam = ws.CurrentCamera
API.player.mouse = getins(API.player.plr, "GetMouse")(API.player.plr)
API.player.plrGui = API.player.plr:WaitForChild("PlayerGui")

API.player.plrStats = nil

local function updcharrefs(char)
	if not char then return end
	API.player.char = char

	local statsFolder = API.player.char:WaitForChild("Stats", 5)
	if statsFolder then
		API.player.plrStats = statsFolder
	end

	API.player.backpack = API.player.plr:WaitForChild("Backpack", 5)

	local hum = char:WaitForChild("Humanoid", 5)
	if not hum then 
		return 
	end
	API.player.hum = hum

	local root = char:WaitForChild("HumanoidRootPart", 5)
	if not root then 
		return 
	end
	API.player.root = root
end

if API.player.char then updcharrefs(API.player.char) end

globalTasks:give(
	API.player.plr.CharacterAdded:Connect(function(char)
		updcharrefs(char)
	end),
	"charAdded"
)

globalTasks:give(
	ws:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		API.player.cam = ws.CurrentCamera
	end),
	"cameraChanged"
)

-------------------------------------------------------------------------------------------------------------------------------

-- game
local placeId = getins(game, "PlaceId")
API.lobby.placeId, API.run.placeId, API.roleplay.placeId = 16116270224, 16552821455, 18984416148

API.lobby.detected = placeId == API.lobby.placeId
API.run.detected = placeId == API.run.placeId
API.roleplay.detected = placeId == API.roleplay.placeId

API.run.gameMap = nil
API.run.roomFolder, API.run.elevator = nil
API.game.plrFolder = API.run.detected and ws:WaitForChild("InGamePlayers") or ws:WaitForChild("Players")

API.run.info = nil
API.run.currentRoom = nil
API.run.freeArea = nil
API.run.twisteds = nil
API.run.items = nil
API.run.machines = nil
API.run.fakeElevator = nil
API.run.puddles = nil

globalTasks:spawn(function()
	if API.game.plrFolder:FindFirstChild(API.player.user) then
		updcharrefs(API.player.char)
	end
end)

globalTasks:give(
	API.game.plrFolder.ChildAdded:Connect(function(child)
		if child.Name == API.player.user then
			updcharrefs(API.player.char)
		end
	end),
	"playerFolderAdded"
)

if API.run.detected then
  runTasks:spawn(function()
    API.run.elevator = ws:WaitForChild("Elevators"):WaitForChild("Elevator")
    API.run.roomFolder = ws:WaitForChild("CurrentRoom")

    local lastRoom = nil

    local function updateReferences()
      runTasks:remove("debounce")

      runTasks:give(
	    task.delay(0.2, function()
          API.run.info = ws:FindFirstChild("Info")
          local newRoom = API.run.getRoom()

          if not newRoom then
            runTasks:remove("roomChildAdded")
            runTasks:remove("roomChildRemoved")
            return
          end

          if API.run.floorUnloading() then
            runTasks:remove("roomChildAdded")
            runTasks:remove("roomChildRemoved")
            return
          end

          runTasks:remove("roomChildAdded")
          runTasks:remove("roomChildRemoved")

          API.run.currentRoom = newRoom
          API.run.freeArea = newRoom:WaitForChild("FreeArea", 10)
          API.run.fakeElevator = API.run.freeArea and API.run.freeArea:WaitForChild("FakeElevator", 10)
          API.run.twisteds = newRoom:WaitForChild("Monsters", 10)
          API.run.items = newRoom:WaitForChild("Items", 10)
          API.run.machines = newRoom:WaitForChild("Generators", 10)
          API.run.puddles = newRoom:WaitForChild("Puddles", 5)

          runTasks:give(newRoom.ChildAdded:Connect(updateReferences), "roomChildAdded")
          runTasks:give(newRoom.ChildRemoved:Connect(updateReferences)"roomChildRemoved")

          if newRoom ~= lastRoom then
            lastRoom = newRoom
          end

          runTasks:give(API.run.roomFolder.ChildAdded:Connect(updateReferences), "roomFolderAdded")
          runTasks:give(API.run.roomFolder.ChildRemoved:Connect(updateReferences), "roomFolderRemoved")
        end),
    	"debounce"
      )
    end
  end)
end

function API.run.getRoom() -- checks if currentroom folder has a parent, returns the folders child or nil
  if API.run.gameMap and API.run.gameMap.Parent then return API.run.gameMap end
  API.run.gameMap = ws.CurrentRoom:FindFirstChildWhichIsA("Model")
          
  if API.run.gameMap then return API.run.gameMap else return nil end
end

function API.run.roomComplete() -- checks if currentroom is missing any components, returns false if so
  if not API.run.currentRoom:FindFirstChild("FreeArea") or
    not API.run.currentRoom:FindFirstChild("Monsters") or
    not API.run.currentRoom:FindFirstChild("Items") or
    not API.run.currentRoom:FindFirstChild("Generators") then
  	return false
  else
    return true
  end
end

function API.run.exists(plr) -- checks if the player exists in the player folder (ingame and not ingame), returns true or false
  local exists, aim = nil, (plr and plr.Name) or API.player.user
  exists = API.game.plrFolder:FindFirstChild(aim) 

  return exists
end

function API.run.floorLoaded() -- returns true if the floor / map has completely loaded
  return API.run.getGameStats().message:find("Doors open")
end

function API.run.floorUnloading() -- returns true if the current floor is unloading
  if API.run.getGameStats().message:find("Quickly") and not API.run.elevator:FindFirstChild("Opened").Value then
	return true
  end
end

function API.run.getGameStats() -- returns the value of the target game stat
  if not API.run.info then return nil end

  local gameStats = {
	gamestarted = API.run.info:FindFirstChild("GameStarted").Value,
	cardvoting = API.run.info:FindFirstChild("CardVoting").Value,
	dandyselling = API.run.info:FindFirstChild("DandyStoreOpen").Value,
	currentfloor = API.run.info:FindFirstChild("Floor").Value,
	flooractive = API.run.info:FindFirstChild("FloorActive").Value,
	panicmode = API.run.info:FindFirstChild("Panic").Value,
	machscompleted = API.run.info:FindFirstChild("GeneratorsCompleted").Value,
	machsrequired = API.run.info:FindFirstChild("RequiredGenerators").Value,
	blackout = API.run.info:FindFirstChild("BlackOut").Value,
	playersalive = API.run.info:FindFirstChild("ActivePlayers").Value,
	boughtnothingfor = API.run.info:FindFirstChild("DandyTracker"):FindFirstChild("NoBuy").Value,
	message = API.run.info:FindFirstChild("Message").Value
  }

  return gameStats
end

-------------------------------------------------------------------------------------------------------------------------------

return API

-------------------------------------------------------------------------------------------------------------------------------
