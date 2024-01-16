local Math = require("Modules/Math")
local Inventory = require("Modules/Inventory")
local SpawnFilters = require("Modules/SpawnFilters")
local Tagging = require("Modules/Tagging")
local Effects = require("Modules/Effects")

local ScriptTuner = Moon.ScriptTuner.GetOrMake()

--Globals
--How many kills it takes to win
WinningKillCount = ScriptTuner:GetInt("GameRules/ScoreLimit", 25)

--Buffer to make sure people don't spawnt too close to living people
SpawnDistanceBuffer = 20000 * 20000

Pistol = { 
	Weapon="AutoPistol", 
	Parts={}
}	

--End Globals

--Configure Game Mode
local GameMode = Moon.GameMode.First()

--Time between automatic respawns
GameMode.RespawnDelay = ScriptTuner:GetInt("Spawn/RespawnDelay", 5)
GameMode.AutomaticRespawn = true

local LootRules = Moon.MatchLootRules.Get()

LootRules.EnableLoot = ScriptTuner:GetBool("LootRules/Enabled", true)
LootRules.EnableDeathbags = ScriptTuner:GetBool("LootRules/Deathbags", true)
LootRules.DeathBagLifetime = 60
LootRules.RespawnLoot = ScriptTuner:GetBool("LootRules/Respawn", true)
LootRules.ContainerRespawnTime = ScriptTuner:GetInt("LootRules/ContainerDelay", 2) * 60
LootRules.PickupRespawnTime = ScriptTuner:GetInt("LootRules/PickupDelay", 1) * 60

GameMode.OnLogin:Connect(function (Player)
	-- Inventory.GrantWeapon(Player, Pistol, true)
	-- Player:GetEquipment():AddItem("HeavyChestArmor")
	-- Player:GetEquipment():AddItem("HeavyHelmet")

	Player:SetInfiniteAmmo(false)

	Effects.AddHealthRegen(Player)
	Player.OnKill:Connect(function(Victim)

		if Moon.PlayerStats.GetKills(Player) >= WinningKillCount then
			GameMode:EndMatch(Player)
			Moon.HudController.Get():AddWidget("MatchStats")
		end
	end)

	Player.OnKilled:Connect(function(Killer)

		if Killer:GetName() == Player:GetName() then
			MS.Utility.Log("Suicide Detected")
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
	MS.Utility.Log("OnRespawn: weapon grant")
	
	Player:GetBackpack():ClearInventory()
	Player:GetEquipment():ClearInventory()

	local Equipment = Player:GetEquipment()
	local Backpack = Player:GetBackpack()
	
	Inventory.GrantWeapon(Player, Pistol, true, true)
	
	MS.Utility.Log("OnRespawn: Finish")
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
ScoreUISettings.MatchDescription = tostring(WinningKillCount) .. " kills to win"
ScoreUISettings.MatchName = "Free For All"
ScoreUISettings.WinLimit = WinningKillCount
ScoreUISettings.DisplayPlayerName = true
ScoreUISettings.ShowPlace = false

MS.Utility.Log("FreeForAll.luau Finished")