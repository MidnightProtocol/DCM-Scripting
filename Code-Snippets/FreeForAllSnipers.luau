local Math = require("Math")
local Inventory = require("Inventory")
local SpawnFilters = require("SpawnFilters")
local Tagging = require("Tagging")

------Globals----------

--How many kills it takes to win
WinningKillCount = 25

-----End Globals------

--Configure Game Mode
local GameMode = Moon.GameMode.First()

--Time between automatic respawns
GameMode.RespawnDelay = 2.0
GameMode.AutomaticRespawn = true

local LootRules = Moon.MatchLootRules.Get()

LootRules.EnableLoot = false
LootRules.EnableDeathbags = false


GameMode.OnLogin:Connect(function (Player)
	Player.OnKill:Connect(function(Victim)

		if Moon.PlayerStats.GetKills(Player) >= WinningKillCount then
			GameMode:EndMatch(Player)
			Moon.HudController.Get():AddWidget("MatchStats")
		end
	end)
end)

GameMode:SetInventoryImportEnabled(false)
GameMode:SetInventoryExportEnabled(false)

GameMode.ShouldRespawn:Connect(function (Player)
	return true
end)

GameMode.GetPawnClass:Connect(function(Player)
	return "Default"
end)

local Sniper = { 
	Weapon="SniperRifle", 
	Parts={"SniperRifleBarrel_B", "SniperRifleChip_B", "SniperRifleGrip_B", "SniperRifleStock_B", "8xPTS-2"}
}

local DeepFreezeShotgun = { 
	Weapon="DeepFreezeShotgun", 
	Parts={}
}

GameMode.OnRespawn:Connect(function(Player)
	MS.Utility.Log("OnRespawn: weapon grant")
	
	Player:GetBackpack():ClearInventory()
	Player:GetEquipment():ClearInventory()

	local Equipment = Player:GetEquipment()
	local Backpack = Player:GetBackpack()
	
	Inventory.GrantWeapon(Player, Sniper, true, true)
	Inventory.GrantWeapon(Player, DeepFreezeShotgun, true, false)
	
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
ScoreUISettings.MatchName = "Shotty Snipers" 
ScoreUISettings.WinLimit = WinningKillCount
ScoreUISettings.DisplayPlayerName = true
ScoreUISettings.ShowPlace = false

MS.Utility.Log("FreeForAllSnipers.luau Finished")