local RisingHazard = require("RisingHazard")
local ExtractionManager = require("ExtractionManager")
local Inventory = require("Inventory")
local Math = require("Math")

--Globals
local OnFirstPlayerJoin = function ()
	RisingHazard.Initialize()
	RisingHazard.Start()

	ExtractionManager.Initialize()
end

--Number of times a player can respawns
RespawnCount = 5
math.randomseed(os.time())

--Tracks how many players are in game in playable state
ValidInGamePlayers = 0

Pistol = { 
	Weapon="AutoPistol", 
	Parts={}
}	

--Squared distance spawn buffer for syns
SynDistanceSpawnBuffer = 20000 * 20000
--End Globals

--Configure Game Mode
local GameMode = Moon.GameMode.First()

--Time between automatic respawns
GameMode.RespawnDelay = 1.0

GameMode.OnLogin:Connect(function (Player)
	if OnFirstPlayerJoin ~= nil then
		OnFirstPlayerJoin()
		OnFirstPlayerJoin = nil
	end

	local PlayerName = Player:GetName()
	MS.Utility.Log("OnLogin: New Player Cycle: " .. PlayerName)

	Player.OnKill:Connect(function(Victim)
		MS.Utility.Log("OnKill: Player" .. PlayerName .. "killed player " .. Vicitm:GetName())
	end);
end)

GameMode.OnMatchAllocated:Connect(function ()
		GameMode:SetInventoryImportEnabled(true)
		GameMode:SetInventoryExportEnabled(true)
end)

GameMode.ShouldRespawn:Connect(function (Player)
	local Name = Player:GetName()
	local DeathCount = Moon.PlayerStats.GetDeaths(Player)
	MS.Utility.Log("Lua Death Count for player state" .. Name .. ": " .. DeathCount)
	
	if DeathCount < RespawnCount + 1 then
		return true
		else
		return false
	end
end)

GameMode.GetPawnClass:Connect(function(Player)
	if Moon.PlayerStats.GetDeaths(Player) > 0 then
		return "Syn"
	end
	
	return "Default"
end)

GameMode.OnRespawn:Connect(function(Player)
	ValidInGamePlayers = ValidInGamePlayers + 1
	
	MS.Utility.Log("OnRespawn: weapon grant")
	
	local PlayerName = Player:GetName()

	Player:GetBackpack():ClearInventory()
	Player:GetEquipment():ClearInventory()

	Inventory.GrantWeapon(Player, Pistol, true, true)

	Inventory.GrantStack(Player:GetBackpack(), "PistolAmmo")
	
	MS.Utility.Log("OnRespawn: Finish")
end)

--[[
	MatchEvent Enum
	
	None = 0
	Success = 1
	Killed = 2
	RanOutOfTime = 3
	Logout = 4
	DeadropWinner = 5 
]]--
	
GameMode.OnPlayerMatchEvent:Connect(function(Player, Event)	
	if Event ~= 0 then
		ValidInGamePlayers = ValidInGamePlayers - 1	
		if ValidInGamePlayers == 1 then
			local Players = Moon.Player.All()
			for i = 1, #Players do
				if Players[i].MatchState == 0 then
				
					local Rewards = Players[i]:GetRewardsContainer()
					
					Inventory.GrantWeaponBlocking(Rewards, Pistol)
					Inventory.GrantWeaponBlocking(Rewards, Pistol)
					Inventory.GrantWeaponBlocking(Rewards, Pistol)
					Inventory.GrantWeaponBlocking(Rewards, Pistol)
					Inventory.GrantWeaponBlocking(Rewards, Pistol)
					
					Moon.Deadrop.AwardDeadrop(Players[i])
				end
			end
        end
	end
end)

function PlayerStartFilter(Player, PlayerStarts)
	
	local OutPlayerStarts = {}
	local DeathCount = Moon.PlayerStats.GetDeaths(Player)
	local Players = Moon.Player.All()
				
	for i = 1, #PlayerStarts do
	
		local bShouldAddStart = false
		
		--Check syn vs skin spawn
		local ExtractionStart = Moon.ExtractionPlayerStart.Cast(PlayerStarts[i])
		if ExtractionStart ~= nil then
				
			if ExtractionStart.CanSpawnSyn == true and DeathCount > 0 then
				bShouldAddStart = true
			end
			
			if ExtractionStart.CanSpawnSkin == true and DeathCount == 0 then
				bShouldAddStart = true
			end
			
			if ExtractionStart.CanSpawnSyn == true and ExtractionStart.CanSpawnSkin == true then
				bShouldAddStart = true
			end
			
		end
		
		--Dist check for syn spawn
		if DeathCount > 0 then
			local StartLoc = PlayerStarts[i]:GetLocation()
			
			for j = 1, #Players do
				local PlayerLoc = Players[j]:GetLocation()
				local SquareDistance = Math.SquaredDist3d(StartLoc, PlayerLoc)
				
				if SquareDistance < SynDistanceSpawnBuffer then
					bShouldAddStart = false
				end
			end
		end
		
		if bShouldAddStart == true then
			table.insert(OutPlayerStarts, PlayerStarts[i])
		end
	end
	
	--If by crazy chance every point is filtered out
	if #OutPlayerStarts == 0 then
		MS.Utility.Log("Lua player filter found no valid player starts. Returning full array")
		return PlayerStarts
	else
		return OutPlayerStarts
	end
end

GameMode:AddPlayerStartFilter(PlayerStartFilter)

Moon.PlayerStats.SetDamageTrackingDuration(15)

MS.Utility.Log("Deadrop.luau Finished")