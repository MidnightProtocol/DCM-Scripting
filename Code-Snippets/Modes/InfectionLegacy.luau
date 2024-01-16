local Inventory = require("Modules/Inventory")
local SpawnFilters = require("Modules/SpawnFilters")
local Effects = require("Modules/Effects")
local MidnightUtility = require("Modules/MidnightUtility")
local Math = require("Modules/Math")
local Rounds = require("Modules/Rounds")
local Outfits = require("Modules/Outfits")
local Audio = require("Modules/Audio")

--Configure Game Mode
local GameMode = Moon.GameMode.First()

local MessageController = Moon.MessageController.Get();
local ScriptTuner = Moon.ScriptTuner.GetOrMake()

--Time between automatic respawns
GameMode.RespawnDelay = ScriptTuner:GetInt("Spawn/RespawnDelay", 1)
GameMode.AutomaticRespawn = true


local LootRules = Moon.MatchLootRules.Get()

LootRules.EnableLoot = ScriptTuner:GetBool("LootRules/Enabled", true)
LootRules.EnableDeathbags = ScriptTuner:GetBool("LootRules/Deathbags", true)
LootRules.RespawnLoot = ScriptTuner:GetBool("LootRules/Respawn", true)
LootRules.ContainerRespawnTime = ScriptTuner:GetInt("LootRules/ContainerDelay", 4) * 60
LootRules.PickupRespawnTime = ScriptTuner:GetInt("LootRules/PickupDelay", 2) * 60

-- Team Settings
local TeamSettings = Moon.Teams.Settings()
TeamSettings.AutoCreateTeams = false
TeamSettings.UseSquadColors = false

--Teams
local Infected = Moon.Teams.GetOrMakeTeam("Infected")
local Human = Moon.Teams.GetOrMakeTeam("Human")

--Spawn Point Tracking
local SpawnPoints = {}

--Effects
--Create an effect with additive modifiers
InfectedEffect = Moon.GameplayEffect.CreateEffect("Additive", 0)
InfectedEffect:SetMagnitude("MoveSpeed", 100)
InfectedEffect:SetMagnitude("MaxHealth", 100)

--LUA GLOBALS--
local StartingInfectedCount = 1
CurrentInfectedCount = 0

Rounds.RoundLength = ScriptTuner:GetInt("GameRules/RoundDuration", 5) * 60

local HumanPingTime = 3.0 * 60.0
local HumanPingInterval = 10

local HumanPingTimerHandle = nil
local DisableHumanSpawnsHandle = nil

local TimeToTurnOffHumanSpawns = 2.0 * 60.0
local AllowHumanSpawns = true

local CustomStatName = "Points"

local PointsForHumanKill = ScriptTuner:GetInt("GameRules/HumanKillPoints", 100)
local PointsForRoundWin = ScriptTuner:GetInt("GameRules/PointsPerRoundWin", 100)
local PointsPerInfectedAlive = ScriptTuner:GetInt("GameRules/SurvivorPoints", 10)
local HumanAwardInterval = ScriptTuner:GetInt("GameRules/SurvivorInterval", 10)
local HumanAwardTimerHandle = nil

local Players = MidnightUtility.MidnightTable.New()
--END LUA GLOBALS--

function DisableHumanSpawns()
	AllowHumanSpawns = false
end

local SemiPistol = 
{
	Weapon = "SemiPistol",
	Parts={}
}

function InitHumanPlayer(Player)
	Player:GetEquipment():AddItem("LargeBackpack")
	
	Inventory.GrantWeapon(Player, SemiPistol, true, true)
	
	Player:GetEquipment():AddItem("Bandage")
	Player:GetEquipment():AddItem("Bandage")
	Player:GetEquipment():AddItem("FragGrenade")
	Player:GetEquipment():AddItem("SmokeGrenade")
	Player:GetEquipment():AddItem("AdrenalineSpray")

	Effects.AddHealthRegen(Player)

	Moon.HudController.GetForPlayer(Player):RemoveWidget("InfectedScreenEffect")

	Player:RemoveTag("Interaction.Block.Loot")
	Player:RemoveTag("Interaction.Block.Lifelink")
end

local Knife = { 
	Weapon="Knife", 
	Parts={}
}

function InitInfectedPlayer(Player)
	Moon.GameplayEffect.ApplyEffect(Player, InfectedEffect)
	Inventory.GrantWeapon(Player, Knife, true, true)

	Effects.RemoveHealthRegen(Player)

	Player:AddTag("Interaction.Block.Loot")
	Player:AddTag("Interaction.Block.Lifelink")

	Outfits.SetOutfit(Player, Outfits.Outfits.Infected)
	Moon.HudController.GetForPlayer(Player):AddWidget("InfectedScreenEffect")

	MS.Utility.SetTimer(function()
		MessageController:SendMessage({Player}, "You Are Infected", 10)
	end, 0.5)
end

GameMode.OnLogout:Connect(function (Player)
	table.remove(Players, MidnightUtility.TableFind(Players, Player))

	if Infected:Size() == 1 and Infected:HasPlayer(Player) and #Players > 0 then
		MidnightUtility.Shuffle(Players)
		
		Infected:AddPlayer(Players[1])
		Players[1]:Reset()
	end

	if Human:Size() == 1 and Human:HasPlayer(Player) then
		Rounds.EndCurrentRound()
	end
end)

GameMode.OnLogin:Connect(function (Player)
	table.insert(Players, Player)

	if CurrentInfectedCount < StartingInfectedCount or AllowHumanSpawns == false then 
		Infected:AddPlayer(Player)
		CurrentInfectedCount = CurrentInfectedCount + 1
	else
		Human:AddPlayer(Player)
	end
	
	Player:SetInfiniteAmmo(false)

	Player.OnKill:Connect(function(Victim)
		if Human:HasPlayer(Player) == true then
			Player:GetBackpack():AddItem("Bandage")
			Player:GetBackpack():AddItem("FragGrenade")
			Player:GetBackpack():AddItem("SmokeGrenade")
			Player:GetBackpack():AddItem("AdrenalineSpray")
		end

		if Human:HasPlayer(Victim) and BetweenRounds == false then
			Moon.PlayerStats.AddCustomStatValue(Player, CustomStatName, PointsForHumanKill)
		end
	end)
	
	Player.OnKilled:Connect(function (Killer)
		--Delete any old spawn point first
		SpawnPoints[Player:GetName()] = nil

		if Human:HasPlayer(Player) then
			Human:RemovePlayer(Player)
			
			if Human:Size() == 1 then
				MessageController:SendMessage(Human:GetTeamMembers(), "Final Survivor", 0)
			end
			if Human:Size() == 0 then
				Rounds.EndCurrentRound()
			end

			if Rounds.GetRoundState() == Rounds.RoundState.MidRound then
				--Try Save the spawn point for this player
				SpawnPoints[Player:GetName()] = SpawnFilters.TryMakeSpawnPointNear(Player:GetLocation(), Player, 250)
			end
		end

		if Infected:HasPlayer(Player) == false then
			Infected:AddPlayer(Player)
			CurrentInfectedCount = CurrentInfectedCount + 1
		end
	end)
end)

GameMode:AddPlayerStartFilter(function(Player, PlayerStarts) 
    local OutPlayerStarts = {}

    if SpawnPoints[Player:GetName()] ~= nil then
        table.insert(OutPlayerStarts, SpawnPoints[Player:GetName()])
        return OutPlayerStarts
    end

    return SpawnFilters.MinimumSpawnDistanceFilter(Player, PlayerStarts)
end)

GameMode.ShouldRespawn:Connect(function (Player)
	return true
end)

GameMode.OnRespawn:Connect(function(Player)
	Player:GetBackpack():ClearInventory()
	Player:GetEquipment():ClearInventory()

	--Init by player
	if Human:HasPlayer(Player) then
		InitHumanPlayer(Player)
	else
		InitInfectedPlayer(Player)
	end
end)

GameMode.GetPawnClass:Connect(function(Player)
	return "Default"
end)

function RestartHumanPointTimer()
  HumanAwardTimerHandle = MS.Utility.SetTimer(
	function ()
		local Humans = Human:GetTeamMembers()
		for i = 1, #Humans do
			Moon.PlayerStats.AddCustomStatValue(Humans[i], CustomStatName, PointsPerInfectedAlive * Infected:Size())
		end
	end, HumanAwardInterval, true)
end

local ScoreUISettings = Moon.ScoreUISettings.Get() 

function HumanPing()
	local Humans = Human:GetTeamMembers()
	for j = 1, #Humans do
		if Humans[j] ~= nil then
			if Humans[j]:IsAlive() then
				Moon.Location.PingLocationWithContext(Math.RandomLocationWithinDistance(Humans[j]:GetLocation(), 1000), Infected, 1, false)
			end
		end
	end		
end

Rounds.SetOnNewRound(function ()
	AllowHumanSpawns = true
	CurrentInfectedCount = 0

	MidnightUtility.Shuffle(Players)

	for i = 1, #Players do
		if CurrentInfectedCount < StartingInfectedCount then
			Infected:AddPlayer(Players[i])
			CurrentInfectedCount = CurrentInfectedCount + 1
		else
			Human:AddPlayer(Players[i])
		end

		Players[i]:Reset()
	end

	
	LootRules:ClearAllDeathBags()

	SpawnPoint = {}

	RestartHumanPointTimer()
	DisableHumanSpawnsHandle = MS.Utility.SetTimer(DisableHumanSpawns, TimeToTurnOffHumanSpawns)
	HumanPingTimerHandle = MS.Utility.SetTimer(HumanPing, HumanPingInterval, true, HumanPingTime)
	ScoreUISettings.MatchDescription = "Round " .. tostring(Rounds.GetCurrentRound()) .. "\nHumans Survive \nInfected Kill."
end)

Rounds.SetOnRoundEndMessage(function ()
	print("Lua test")
	if Human:Size() == 0 then
		return "Round Ended - All Survivors Have Been Infected"
	else
		return "Round Ended - Survivors Lived"
	end
end)

Rounds.SetOnRoundEnd(function()
	
	Moon.AudioController.PlayGlobalSound({Sound=Audio.Sound.LargeObjectiveThree, VolumeMultiplier=0.6})

	MS.Utility.ClearTimer(HumanAwardTimerHandle)
	MS.Utility.ClearTimer(HumanPingTimerHandle)
	MS.Utility.ClearTimer(DisableHumanSpawnsHandle)
	HumanAwardTimerHandle = nil
	HumanPingTimerHandle = nil
	DisableHumanSpawnsHandle = nil

	AwardTeam = nil

	if Human:Size() == 0 then
		AwardTeam = Infected
	else
		AwardTeam = Human
	end

	if AwardTeam ~= nil then
		local Members = AwardTeam:GetTeamMembers()
		for i = 1, #Members do
			Moon.PlayerStats.AddCustomStatValue(Members[i], CustomStatName, PointsForRoundWin)
		end
	end
end)

function AssignWinners()
	local WinningPlayer = nil
	local HighCount = 0
	for i = 1, #Players do
		local Score = Moon.PlayerStats.GetCustomStatValue(Players[i], CustomStatName, PointsForRoundWin)

		if (Score > HighCount) then
			HighCount = Score
			WinningPlayer = Players[i]
		end
	end

	GameMode:EndMatch(WinningPlayer)
	ScoreUISettings.MatchDescription = "Match Over"
	Moon.HudController.Get():AddWidget("MatchStats")
end

Rounds.SetOnMatchEnd(AssignWinners)

Rounds.Start()

local HudController = Moon.HudController.Get()
HudController:AddWidget("ScoreBug")
HudController:AddWidget("TeamIndicators")

ScoreUISettings.StatName = CustomStatName
ScoreUISettings.ShowScore = true
ScoreUISettings.ShowPlace = true
ScoreUISettings.OnlyShowLocalScore = false
ScoreUISettings.MatchName = "Infection"
ScoreUISettings.DisplayPlayerName = true
ScoreUISettings.ShowTeamName = true
ScoreUISettings.ShowClock = true
ScoreUISettings.IsTeamMatch = false

local Columns = ScoreUISettings.MatchStatColumns
table.insert(Columns, 1, CustomStatName)
ScoreUISettings.MatchStatColumns = Columns

MS.Utility.Log("Infection.luau Finished")