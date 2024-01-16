local Inventory = require("Modules/Inventory")
local GunCycle = require("Modules/GunGame_WeaponCycles")
local SpawnFilters = require("Modules/SpawnFilters")
local Math = require("Modules/Math")
local Tagging = require("Modules/Tagging")
local Outfits = require("Modules/Outfits")
local Effects = require("Modules/Effects")

--Globals

--Number of times a player can respawns
local RespawnCount = 5
math.randomseed(os.time())

WeaponCycle = GunCycle.MakeCycle()

--End Globals

--Configure Game Mode
local GameMode = Moon.GameMode.First()
local ScriptTuner = Moon.ScriptTuner.GetOrMake()

--Time between automatic respawns
GameMode.RespawnDelay = ScriptTuner:GetInt("Spawn/RespawnDelay", 5)
GameMode.AutomaticRespawn = true

local LootRules = Moon.MatchLootRules.Get()

LootRules.EnableLoot = false
LootRules.EnableDeathbags = false

local LeadingPlayers = {}
local LeadingIndex = 3

function Ping()
	for j = 1, #LeadingPlayers do
		if LeadingPlayers[j] ~= nil then
			if LeadingPlayers[j]:IsAlive() then
				Moon.Location.PingLocation(LeadingPlayers[j]:GetLocation(), 1, false)
			end
		end	
	end	
end

PingTimer = MS.Utility.SetTimer(Ping, 5.0, true)
			
GameMode.OnLogin:Connect(function (Player)
	local PlayerName = Player:GetName()
	MS.Utility.Log("OnLogin: New Player Cycle: " .. PlayerName)

	Effects.AddHealthRegen(Player)

	Player:GetEquipment():AddItem("HeavyChestArmor")
	Player:GetEquipment():AddItem("HeavyHelmet")
	Player:GetEquipment():AddItem("Thruster")
	Player:GetEquipment():AddItem("Bandage")
	
	local CurrentIndex = GunCycle.TryGrantCycleWeapon(Player, WeaponCycle, true)

	Player.OnKill:Connect(function(Victim)
		Player:GetEquipment():ClearInventory()
		Player:GetBackpack():ClearInventory()
		
		Player:GetEquipment():AddItem("HeavyChestArmor")
		Player:GetEquipment():AddItem("HeavyHelmet")
		Player:GetEquipment():AddItem("Thruster")
		Player:GetEquipment():AddItem("Bandage")
		
		local CurrentIndex = GunCycle.TryGrantCycleWeapon(Player, WeaponCycle, true)
				
		if CurrentIndex > #WeaponCycle then
			GameMode:EndMatch(Player)
			Moon.HudController.Get():AddWidget("MatchStats")	
		end

		if CurrentIndex == LeadingIndex then
			table.insert(LeadingPlayers, Player)
		end
		
		if CurrentIndex > LeadingIndex then
			LeadingPlayers = {}
			table.insert(LeadingPlayers, Player)
			LeadingIndex = CurrentIndex
		end
	end)

	
	Player.OnKilled:Connect(function(Killer)
		if Killer:GetName() == Player:GetName() then
			print("Lua main: self term")
			Player:GetEquipment():ClearInventory()
			Player:GetBackpack():ClearInventory()
			
			Player:GetEquipment():AddItem("HeavyChestArmor")
			Player:GetEquipment():AddItem("HeavyHelmet")
			Player:GetEquipment():AddItem("Thruster")
			Player:GetEquipment():AddItem("Bandage")
			GunCycle.TryGrantCycleWeapon(Player, WeaponCycle, false)
		end
	end)

end)

GameMode.ShouldRespawn:Connect(function (Player)
	return true
end)

GameMode.GetPawnClass:Connect(function(Player)
	return "Default"
end)

GameMode.OnRespawn:Connect(function(Player)
	Outfits.SetRandomOutfit(Player)
end)

GameMode:AddPlayerStartFilter(SpawnFilters.MinimumSpawnDistanceFilter)
GameMode:AddPlayerStartFilter(function (Player, PlayerStarts)
	local OutPlayerStarts = Tagging.FilterByTag(PlayerStarts, "Spawn.FFA")
	
	if #OutPlayerStarts == 0 then
		MS.Utility.Log("Lua player filter found no valid player starts. Returning full array")
		return PlayerStarts
	else
		return OutPlayerStarts
	end
end)

Moon.PlayerStats.SetDamageTrackingDuration(15)

local HudController = Moon.HudController.Get()
HudController:AddWidget("ScoreBug")

local ScoreUISettings = Moon.ScoreUISettings.Get()
ScoreUISettings.MatchDescription = "Get eliminations with each weapon"
ScoreUISettings.MatchName = "Gun Game" 
ScoreUISettings.WinLimit = table.getn(GunCycle.MakeCycle())
ScoreUISettings.DisplayPlayerName = true
ScoreUISettings.ShowPlace = false

MS.Utility.Log("GunGame.luau Finished")