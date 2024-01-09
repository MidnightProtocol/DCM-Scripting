local Math = require("Math")
local Inventory = require("Inventory")
local SpawnFilters = require("SpawnFilters")
local Tagging = require("Tagging")
local Effects = require("Effects")
local MidnightUtility = require("MidnightUtility")
local Outfits = require("Outfits")
local Audio = require("Audio")

local ScriptTuner = Moon.ScriptTuner.GetOrMake()

--Configure Game Mode
local GameMode = Moon.GameMode.First()
local MatchSize = GameMode:MatchSize()
LevelVariatonTag = nil

local PlayerBotManager = Moon.PlayerBotManager.Get()
local NumberOfPlayersBots = ScriptTuner:GetInt("GameRules/PlayerBots", 0)
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

-- Team Settings
local TeamSettings = Moon.Teams.Settings()
TeamSettings.AutoCreateTeams = false
TeamSettings.UseSquadColors = false

--Globals
--How many kills it takes to win
WinningKillCount = 5
WinningKillCountMinimum = ScriptTuner:GetInt("GameRules/ScoreLimit", 5)

EnableKingPlayer = true
KingPlayerLead = 5

RoundTime = ScriptTuner:GetInt("GameRules/TimeLimit", 20) * 60

local ScoreTracker = MidnightUtility.MidnightTable.New()

--Loadouts
local LoadOutTracker = MidnightUtility.MidnightTable.New()
local NumOfPlayers = 0
local Loadouts = {}

local LoadoutOne = {}
local LoadoutTwo = {}
local LoudoutThree = {}

table.insert(Loadouts, LoadoutOne)
table.insert(Loadouts, LoadoutTwo)
table.insert(Loadouts, LoudoutThree)

local Armor = { Helmet = "HeavyHelmet", Chest = "HeavyChestArmor"}
local Grenades = {"FragGrenade", "SmokeGrenade"}

local AssaultRifle = {Weapon = "AssaultRifle", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "3xReflex-1"}}
local HeavyPistol = {Weapon = "HeavyPistol", Parts={"BarrelIV", "GripIV", "BlueLaser", "4xPTS-1"}}
local SMG = {Weapon = "SMG", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser"}}
local DMR = {Weapon = "DMR", Parts={"BarrelIV", "GripIV", "StockIV", "4xPTS-1"}}
local Sniper = {Weapon = "SniperRifle", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "8xPTS-2"}}
local PumpShotgun = {Weapon = "PumpShotgun", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser"}}

LoadoutOne.PrimaryWeapon = AssaultRifle
LoadoutOne.SecondaryWeapon = HeavyPistol
LoadoutOne.Grenades = Grenades
LoadoutOne.Armor = Armor

LoadoutTwo.PrimaryWeapon = SMG
LoadoutTwo.SecondaryWeapon = DMR
LoadoutTwo.Grenades = Grenades
LoadoutTwo.Armor = Armor

LoudoutThree.PrimaryWeapon = Sniper
LoudoutThree.SecondaryWeapon = PumpShotgun
LoudoutThree.Grenades = Grenades
LoudoutThree.Armor = Armor

KingPlayer = nil
--End Globals

GameMode:SetInventoryImportEnabled(false)
GameMode:SetInventoryExportEnabled(false)

--Respans
GameMode.RespawnDelay = ScriptTuner:GetInt("Spawn/RespawnDelay", 5)
GameMode.AutomaticRespawn = true

--Loot rules
local LootRules = Moon.MatchLootRules.Get()
LootRules.EnableLoot = ScriptTuner:GetBool("LootRules/Enabled", false)
LootRules.EnableDeathbags = ScriptTuner:GetBool("LootRules/Deathbags", true)
LootRules.DeathBagLifetime = ScriptTuner:GetInt("LootRules/DeathbagLifetimes", 60)
LootRules.RespawnLoot = ScriptTuner:GetBool("LootRules/Respawn", false)
LootRules.ContainerRespawnTime = ScriptTuner:GetInt("LootRules/ContainerDelay", 2) * 60
LootRules.PickupRespawnTime = ScriptTuner:GetInt("LootRules/PickupDelay", 1) * 60

--Timer
GameMode:SetMatchClock(RoundTime)
MS.Utility.SetTimer(function ()

	local WinningPlayer = nil
	local WinningScore = -1

	for key, value in pairs(ScoreTracker) do 
		if value.Score > WinningScore and value.Player ~= nil then
			WinningPlayer = value.Player
		end
	end

	GameMode:EndMatch(WinningPlayer)
	Audio.PlayGlobalSound({Sound=Audio.Sound.LargeEnderOne})
	Moon.HudController.Get():AddWidget("MatchStats")
end, RoundTime)

--Health Regen
Effects.TuneHealthRegen(5, 0.2)

local GlobalObjectives = Moon.ObjectiveSettings.Get()
local KingKillObjectiveHandle = nil

local MessageController = Moon.MessageController.Get()

function MakeKingPlayer(Player)
	KingPlayer = Player
	KingKillObjectiveHandle = GlobalObjectives:AddObjective({TargetActor=KingPlayer, IndicatorType="Indicator.Objective.Enforcer", IndicatorOffset={X=0,Y=0,Z=20}})
	MessageController:SendMessage({KingPlayer}, "You are marked as the king player", 5)
end

function RemoveKingPlayer()
	if KingPlayer ~= nil then
		GlobalObjectives:RemoveObjective(KingKillObjectiveHandle)
		MessageController:SendMessage({KingPlayer}, "You are no longer the king player", 5)
		KingPlayer = nil
	end
end

local ScoreUISettings = Moon.ScoreUISettings.Get()
GameMode.OnLogin:Connect(function (Player)
	Effects.AddHealthRegen(Player)

	LoadOutTracker[Player] = 0
	ScoreTracker[Player] = {PlayerObj=Player, Score=0}

	if PlayerBotManager:IsPlayerABot(Player) == false then
		NumOfPlayers = NumOfPlayers + 1
	end

	local NewTargetScore = math.max(WinningKillCountMinimum, NumOfPlayers) + NumberOfPlayersBots

	ScoreUISettings.WinLimit = NewTargetScore
	ScoreUISettings.MatchDescription = tostring(NewTargetScore) .. " kills to win"
	WinningKillCount = NewTargetScore

	Player.OnKill:Connect(function(Victim)
		KillCount = Moon.PlayerStats.GetKills(Player)

		ScoreTracker[Player].Score = KillCount

		if KillCount >= WinningKillCount then
			GameMode:EndMatch(Player)
			Moon.HudController.Get():AddWidget("MatchStats")
		end

		if KingPlayer ~= nil and Player:GetName() ~= KingPlayer:GetName() then
			if KillCount > Moon.PlayerStats.GetKills(KingPlayer) - KingPlayerLead then
				RemoveKingPlayer()
			end

		end

		if KingPlayer == nil or Player:GetName() ~= KingPlayer:GetName() then	
			local ShouldMakeKingPlayer = true

			for key, value in pairs(ScoreTracker) do 
				if value.Score > KillCount - KingPlayerLead and value.PlayerObj:GetName() ~= Player:GetName() then
					ShouldMakeKingPlayer = false
					break
				end
			end

			if ShouldMakeKingPlayer then
				MakeKingPlayer(Player)
			end
		end

	end)
			
	if NumOfPlayers + NumberOfPlayersBots > 30 then
		PlayerBotManager:RemoveRandomPlayerBot()
	end
end)

GameMode.OnLogout:Connect(function (Player)
	ScoreTracker[Player] = nil
end)

GameMode.OnRespawn:Connect(function(Player)
	if KingPlayer ~= nil and KingPlayer:GetName() == Player:GetName() then
		MakeKingPlayer(Player)
	end
end)

GameMode.ShouldRespawn:Connect(function (Player)
	return true
end)

function AwardNextLoadout(Player, Loadout)
	Player:GetEquipment():AddItem("LargeBackpack")
	
	Inventory.GrantWeapon(Player, Loadout.PrimaryWeapon, true, true)
	Inventory.GrantWeapon(Player, Loadout.SecondaryWeapon, true, false)
	
	Player:GetEquipment():AddItem(Loadout.Armor.Helmet)
	Player:GetEquipment():AddItem(Loadout.Armor.Chest)

	for i = 1, #Loadout.Grenades do
		Player:GetEquipment():AddItem(Loadout.Grenades[i])
	end
end

GameMode.OnRespawn:Connect(function(Player)
	Player:GetBackpack():ClearInventory()
	Player:GetEquipment():ClearInventory()

	AwardNextLoadout(Player, Loadouts[LoadOutTracker[Player] % #Loadouts + 1])
	LoadOutTracker[Player] = LoadOutTracker[Player] + 1
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
HudController:AddWidget("ObjectiveIndicators")

ScoreUISettings.MatchName = "Free For All"
ScoreUISettings.DisplayPlayerName = true
ScoreUISettings.ShowPlace = false
ScoreUISettings.ShowClock = true

MS.Utility.Log("FreeForAll.luau Finished")