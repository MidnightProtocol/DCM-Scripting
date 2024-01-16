local Math = require("Modules/Math")
local Inventory = require("Modules/Inventory")
local SpawnFilters = require("Modules/SpawnFilters")
local Tagging = require("Modules/Tagging")

--Configure Game Mode
local GameMode = Moon.PreGameMode.First()

-- Team Settings
local TeamSettings = Moon.Teams.Settings()
TeamSettings.AutoCreateTeams = false
TeamSettings.UseSquadColors = false

--Globals
--How many kills it takes to win
WinningKillCount = 25

--Buffer to make sure people don't spawnt too close to living people
SpawnDistanceBuffer = 20000 * 20000

Pistol = { 
	Weapon="AutoPistol", 
	Parts={}
}	

local ScoreStateName = "PlayersInLobby"
local CurrentPlayers = 0
local Players = {}

local ScoreUISettings = Moon.ScoreUISettings.Get()
ScoreUISettings.StatName = ScoreStateName
ScoreUISettings.DisplayPlayerName = false
ScoreUISettings.ShowPlace = false
ScoreUISettings.OnlyShowLocalScore = true
ScoreUISettings.ShowClock = true
ScoreUISettings.ShowScore = false
ScoreUISettings.IsTeamMatch = false
ScoreUISettings.ShowTeamName = false
ScoreUISettings.WinLimit = 30
ScoreUISettings.HideScores = true
--ScoreUISettings.MatchName = "Pre-Game Lobby"
--End Globals


--Time between automatic respawns
GameMode.RespawnDelay = 0.1
GameMode.AutomaticRespawn = true

local LootRules = Moon.MatchLootRules.Get()

LootRules.EnableLoot = true
LootRules.EnableDeathbags = true
LootRules.DeathBagLifetime = 60
LootRules.RespawnLoot = true
LootRules.ContainerRespawnTime = 2 * 60
LootRules.PickupRespawnTime = 1 * 60


GameMode.ShouldRespawn:Connect(function (Player)
	return true
end)

GameMode.GetPawnClass:Connect(function(Player)
	return "Default"
end)


local HudController = Moon.HudController.Get()

GameMode.OnMatchKickOff:Connect(function()
	HudController:AddWidget("MatchStarting")
end)

local MessageController = Moon.MessageController.Get()

GameMode.OnLogin:Connect(function(Player)

	MS.Utility.SetTimer(function()
		MessageController:SendMessage({Player}, "Pre-Game Lobby", 0)
	end, 3)

	table.insert(Players, Player)

	CurrentPlayers = CurrentPlayers + 1

	for i = 1, #Players do
		local CurrentStat = Moon.PlayerStats.SetCustomStatValue(Players[i], ScoreStateName, CurrentPlayers)
	end

end)

function TableFind(tab,el)
	for index, value in pairs(tab) do
		if value == el then
			return index
		 end
	end
end

GameMode.OnLogout:Connect(function(Player)

	table.remove(Players, TableFind(Players, Player))

	CurrentPlayers = CurrentPlayers - 1
	
	for i = 1, #Players do
		local CurrentStat = Moon.PlayerStats.SetCustomStatValue(Players[i], ScoreStateName, CurrentPlayers)
	end

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

HudController:AddWidget("ScoreBug")

MS.Utility.Log("EndlessFreeForAll.luau Finished")