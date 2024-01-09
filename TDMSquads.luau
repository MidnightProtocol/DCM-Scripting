local Inventory = require("Inventory")
local SpawnFilters = require("SpawnFilters")
local Effects = require("Effects")
local Tagging = require("Tagging")
local TeamCreation = require("TeamCreation")
local Audio = require("Audio")

--Configure Game Mode
local GameMode = Moon.GameMode.First()
local MatchSize = GameMode:MatchSize()
LevelVariatonTag = nil


local ScriptTuner = Moon.ScriptTuner.GetOrMake()

local PlayerBotManager = Moon.PlayerBotManager.Get()
local NumberOfPlayersBots = ScriptTuner:GetInt("GameRules/PlayerBots", 9)
PlayerBotManager:SpawnPlayerBots(NumberOfPlayersBots)

if MatchSize + NumberOfPlayersBots <= 6 then
    LevelVariatonTag = "Moon.LevelVariation.Small"
elseif MatchSize + NumberOfPlayersBots <= 18 then
    LevelVariatonTag = "Moon.LevelVariation.Medium"
else
    LevelVariatonTag = nil
end


if LevelVariatonTag ~= nil then
    Moon.LevelVariation.LoadLevelVariation(LevelVariatonTag)
end

local ScriptTuner = Moon.ScriptTuner.GetOrMake()

LeadingTeam = nil
LeadingScore = 0

--Time between automatic respawns
GameMode.RespawnDelay = ScriptTuner:GetInt("Spawn/RespawnDelay", 1)
GameMode.AutomaticRespawn = true

local LootRules = Moon.MatchLootRules.Get()
LootRules.EnableLoot = ScriptTuner:GetBool("Loot/Enabled", true)
LootRules.EnableDeathbags = ScriptTuner:GetBool("Loot/Deathbags", true)
LootRules.DeathBagLifetime = ScriptTuner:GetInt("Loot/DeathbagLifetimes", 60)
LootRules.RespawnLoot = ScriptTuner:GetBool("Loot/Respawn", true)
LootRules.ContainerRespawnTime = ScriptTuner:GetInt("Loot/ContainerDelay", 3) * 60
LootRules.PickupRespawnTime = ScriptTuner:GetInt("Loot/PickupDelay", 1) * 60

-- Team Settings
local TeamSettings = Moon.Teams.Settings()
TeamSettings.AutoCreateTeams = false

GameMode:SetInventoryImportEnabled(false)
GameMode:SetInventoryExportEnabled(false)
		
--Teams
TeamCreation.GroupByMatchmakingTeam = true
TeamCreation.DynamicTeaming = true
TeamCreation.AutoCreateTeams = false
TeamCreation.TeamSizes = 3
TeamCreation.Initialize(TeamCreation)

--LUA GLOBALS--
local WinningKillCount = ScriptTuner:GetInt("GameRules/ScoreLimit", 25)

local TeamScores = {}
--END LUA GLOBALS--

--Weapons
local AssaultRifle = { 
	Weapon="AssaultRifle", 
	Parts={}
}

local SemiPistol = { 
	Weapon="SemiPistol", 
	Parts={}
}

local Knife = { 
	Weapon="Knife", 
	Parts={}
}
--End Weapons

function InitPlayer(Player)
	Player:GetEquipment():ClearInventory()
	Player:GetBackpack():ClearInventory()
	Player:GetEquipment():AddItem("LargeBackpack")
	Player:SetInfiniteAmmo(false)
	Inventory.GrantWeapon(Player, SemiPistol, true, false)
	Inventory.GrantWeapon(Player, AssaultRifle, true, true)
	Inventory.GrantWeapon(Player, Knife)
	Inventory.GrantStack(Player:GetBackpack(), "RifleAmmo")
	Inventory.GrantStack(Player:GetBackpack(), "PistolAmmo")
	Effects.AddHealthRegen(Player)
end

local ScoreUISettings = Moon.ScoreUISettings.Get()

function AssignWinners(Team)
	Audio.PlayGlobalSound({Sound=Audio.Sound.LargeEnderOne})
	GameMode:EndMatch(Team:GetTeamMembers())
	ScoreUISettings.MatchDescription = Team:GetDisplayName() .. " Team Wins"
	Moon.HudController.Get():AddWidget("MatchStats")
end

GameMode.OnLogin:Connect(function (Player)
	Player.OnKill:Connect(function(Victim)
		local KillersTeam = Moon.Team.GetPlayersTeam(Player)
		local VictimsTeam = Moon.Team.GetPlayersTeam(Victim)
		
		if KillersTeam:GetName() ~= VictimsTeam:GetName() then
			if TeamScores[KillersTeam:GetName()] == nil then
				TeamScores[KillersTeam:GetName()] = 1
			else
				TeamScores[KillersTeam:GetName()] = TeamScores[KillersTeam:GetName()] + 1
			end
			
			if TeamScores[KillersTeam:GetName()] > LeadingScore then
				LeadingScore = TeamScores[KillersTeam:GetName()]
				LeadingTeam = KillersTeam
			end

			if TeamScores[KillersTeam:GetName()] >= WinningKillCount then
				AssignWinners(KillersTeam)
			end
		end
	end)
	
	Effects.AddHealthRegen(Player)
end)

GameMode.OnRespawn:Connect(function (Player)
	InitPlayer(Player)
end)

GameMode:AddPlayerStartFilter(SpawnFilters.MinimumSpawnDistanceFilter)
GameMode:AddPlayerStartFilter(SpawnFilters.CloseToTeamFilter)
GameMode:AddPlayerStartFilter(function (Player, PlayerStarts)
	local OutPlayerStarts = Tagging.FilterByTag(PlayerStarts, "Spawn.FFA")
	
	if #OutPlayerStarts == 0 then
		MS.Utility.Log("Lua player filter found no valid player starts. Returning full array")
		return PlayerStarts
	else
		return OutPlayerStarts
	end
end)

GameMode.ShouldRespawn:Connect(function (Player)
	return true
end)

GameMode.GetPawnClass:Connect(function(Player)
	return "Default"
end)

Moon.PlayerStats.SetDamageTrackingDuration(15)

MatchTime = ScriptTuner:GetInt("GameRules/TimeLimit", 20) * 60
GameMode:SetMatchClock(MatchTime)
MS.Utility.SetTimer(function ()
	GameMode:EndMatch(LeadingTeam)
	Audio.PlayGlobalSound({Sound=Audio.Sound.LargeEnderOne})
	Moon.HudController.Get():AddWidget("MatchStats")
end, MatchTime)

local HudController = Moon.HudController.Get()
HudController:AddWidget("ScoreBug")
HudController:AddWidget("TeamHealth")
HudController:AddWidget("TeamIndicators")

ScoreUISettings.MatchDescription = tostring(WinningKillCount) .. " kills to win"
ScoreUISettings.MatchName = "Squad Death Match" 
ScoreUISettings.WinLimit = WinningKillCount
ScoreUISettings.DisplayPlayerName = false
ScoreUISettings.ShowTeamName = true
ScoreUISettings.ShowPlace = false
ScoreUISettings.IsTeamMatch = true

MS.Utility.Log("TDMSquads.luau Finished")