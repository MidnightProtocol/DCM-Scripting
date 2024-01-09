local Inventory = require("Inventory")
local SpawnFilters = require("SpawnFilters")
local Effects = require("Effects")
local Tagging = require("Tagging")
local MidnightUtility = require("MidnightUtility")
local TeamCreation = require("TeamCreation")
local Audio = require("Audio")

--Configure Game Mode
--Configure Game Mode
local GameMode = Moon.GameMode.First()
local MatchSize = GameMode:MatchSize()
LevelVariatonTag = nil


local ScriptTuner = Moon.ScriptTuner.GetOrMake()

local PlayerBotManager = Moon.PlayerBotManager.Get()
local NumberOfPlayersBots = ScriptTuner:GetInt("GameRules/PlayerBots", 16)
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
TeamSettings.UseSquadColors = false

GameMode:SetInventoryImportEnabled(false)
GameMode:SetInventoryExportEnabled(false)
		
--Teams
TeamCreation.AddTeam("Red", {R=0.846873, G=0.009721, B=0.048172, A=1.0})
TeamCreation.AddTeam("Blue", {R=0.009721, G=0.351532, B=0.846873, A=1.0})
TeamCreation.Initialize(TeamCreation)

--LUA GLOBALS--
local WinningKillCount = ScriptTuner:GetInt("GameRules/ScoreLimit", 69)
local TeamScores = {}
local KillStreaks = MidnightUtility.MidnightTable.New()
local KillStreakLimit = 10
--END LUA GLOBALS--

--Loadouts
local UseRandomLoadouts = ScriptTuner:GetBool("GameRules/RandomLoadouts", true)
local BasicLoadOut = {}
BasicLoadOut.PrimaryWeapon = {Weapon = "AssaultRifle", Parts={}}
BasicLoadOut.SecondaryWeapon = {Weapon = "SemiPistol", Parts={}}
BasicLoadOut.Equipment = {"FragGrenade", "SmokeGrenade", "Bandage"}
BasicLoadOut.Armor = { Helmet = "LightHelmet", Chest = "LightChestArmor"}
BasicLoadOut.Ammo = {"RifleAmmo", "PistolAmmo"}


local LoadOutTracker = MidnightUtility.MidnightTable.New()
local Loadouts = {}

local LoadoutOne = {}
local LoadoutTwo = {}
local LoudoutThree = {}
local LoudoutFour = {}
local LoudoutFive = {}
local LoudoutSix = {}

table.insert(Loadouts, LoadoutOne)
table.insert(Loadouts, LoadoutTwo)
table.insert(Loadouts, LoudoutThree)

local Armor = { Helmet = "LightHelmet", Chest = "LightChestArmor"}
local Equipment = {"FragGrenade", "SmokeGrenade", "Bandage", "Thruster"}

local AssaultRifle = {Weapon = "AssaultRifle", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "3xReflex-1"}}
local HeavyPistol = {Weapon = "HeavyPistol", Parts={"BarrelIV", "GripIV", "BlueLaser", "2xHolo-1"}}
local SMG = {Weapon = "SMG", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser"}}
local DMR = {Weapon = "DMR", Parts={"BarrelIV", "GripIV", "StockIV", "4xPTS-1"}}
local Sniper = {Weapon = "SniperRifle", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "8xPTS-2"}}
local PumpShotgun = {Weapon = "PumpShotgun", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser"}}
local LMG = {Weapon = "LMG", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "3xReflex-1"}}
local DoubleBarrel = {Weapon = "DoubleBarrel", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "2xHolo-1"}}
local Knife = {Weapon = "Knife", Parts={}}
local SemiPistol = {Weapon = "SemiPistol", Parts={"BarrelIV", "GripIV", "BlueLaser", "2xHolo-1"}}
local AutoShotgun = {Weapon = "AutoShotgun", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser"}}
local AutoPistol = {Weapon = "AutoPistol", Parts={"BarrelIV", "GripIV", "BlueLaser", "2xHolo-1"}}
local DeepFreezeSmg = {Weapon = "DeepFreezeSMG", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "2xHolo-1"}}

LoadoutOne.PrimaryWeapon = DMR
LoadoutOne.SecondaryWeapon = SemiPistol
LoadoutOne.Equipment = {"FragGrenade", "Bandage"}
LoadoutOne.Armor = { Helmet = "MediumHelmet", Chest = "MediumChestArmor"}
LoadoutOne.Ammo = {"RifleAmmo", "PistolAmmo"}

LoadoutTwo.PrimaryWeapon = AutoPistol
LoadoutTwo.SecondaryWeapon = AutoShotgun
LoadoutTwo.Equipment = {"FragGrenade", "Bandage", "Bandage", "Thruster"}
LoadoutTwo.Armor = { Helmet = "HeavyHelmet", Chest = "MediumChestArmor" }
LoadoutTwo.Ammo = {"PistolAmmo", "ShotgunAmmo"}

LoudoutThree.PrimaryWeapon = AssaultRifle
LoudoutThree.SecondaryWeapon = DeepFreezeSmg
LoudoutThree.Equipment = {"SmokeGrenade",  "Bandage"}
LoudoutThree.Armor = { Helmet = "LightHelmet", Chest = "LightChestArmor" }
LoudoutThree.Ammo = {"RifleAmmo", "PistolAmmo"}

LoudoutFour.PrimaryWeapon = SMG
LoudoutFour.SecondaryWeapon = AutoShotgun
LoudoutFour.Equipment = Equipment
LoudoutFour.Armor = Armor
LoudoutFour.Ammo = {"ShotgunAmmo", "PistolAmmo"}

LoudoutFive.PrimaryWeapon = DMR
LoudoutFive.SecondaryWeapon = AutoPistol
LoudoutFive.Equipment = Equipment
LoudoutFive.Armor = Armor
LoudoutFive.Ammo = {"PistolAmmo", "RifleAmmo"}

LoudoutSix.PrimaryWeapon = AssaultRifle
LoudoutSix.SecondaryWeapon = SemiPistol
LoudoutSix.Equipment = Equipment
LoudoutSix.Armor = Armor
LoudoutSix.Ammo = {"PistolAmmo", "RifleAmmo"}
--End Weapons

function AwardNextLoadout(Player, Loadout)
	Player:GetEquipment():AddItem("LargeBackpack")
	
	Inventory.GrantWeapon(Player, Loadout.PrimaryWeapon, true, true)
	Inventory.GrantWeapon(Player, Loadout.SecondaryWeapon, true, false)
	
	Player:GetEquipment():AddItem(Loadout.Armor.Helmet)
	Player:GetEquipment():AddItem(Loadout.Armor.Chest)

	for i = 1, #Loadout.Equipment do
		Player:GetEquipment():AddItem(Loadout.Equipment[i])
	end

	for i = 1, #Loadout.Ammo do
		Inventory.GrantStack(Player:GetBackpack(), Loadout.Ammo[i])
	end
end

function InitPlayer(Player)
	Player:GetEquipment():ClearInventory()
	Player:GetBackpack():ClearInventory()
	if UseRandomLoadouts then
		AwardNextLoadout(Player, Loadouts[math.random(1, #Loadouts)])
	else
		AwardNextLoadout(Player, BasicLoadOut)
	end
end

local ScoreUISettings = Moon.ScoreUISettings.Get()

function AssignWinners(Team)
	Audio.PlayGlobalSound({Sound=Audio.Sound.LargeEnderOne})
	PlayerBotManager:RemoveAllPlayerBots()
	ScoreUISettings.MatchDescription = Team:GetDisplayName() .. " Team Wins"
	GameMode:EndMatch(Team:GetTeamMembers())
	Moon.HudController.Get():AddWidget("MatchStats")
end

local GlobalObjectives = Moon.ObjectiveSettings.Get()
local MessageController = Moon.MessageController.Get()

function AddToKillStreak(Player)
	KillStreaks[Player].CurrentStreak = KillStreaks[Player].CurrentStreak + 1

	if KillStreaks[Player].CurrentStreak >= KillStreakLimit and KillStreaks[Player].ObjectiveHandle == nil then
		KillStreaks[Player].ObjectiveHandle = GlobalObjectives:AddObjective({TargetActor=Player, IndicatorType="Indicator.Objective.Enforcer", IndicatorColor={R=1.0, G=1.0, B=1.0, A=1.0}, IndicatorOffset={X=0,Y=0,Z=20}})
		MessageController:SendMessage({Player}, "You Are On A Streak", 0)
	end
end

function RemoveKillStreak(Player)
	if KillStreaks[Player].ObjectiveHandle ~= nil then
		GlobalObjectives:RemoveObjective(KillStreaks[Player].ObjectiveHandle)
		KillStreaks[Player].ObjectiveHandle = nil
		MessageController:SendMessage({Player}, "Streak Ended", 5)
	end
	KillStreaks[Player].CurrentStreak = 0
end

GameMode.OnLogin:Connect(function (Player)
	Player:SetInfiniteAmmo(false)
	KillStreaks[Player] = {CurrentStreak = 0, ObjectiveHandle = nil}

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

			AddToKillStreak(Player)
		end
	end)

	Player.OnKilled:Connect(function(Killer)
		RemoveKillStreak(Player)
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
HudController:AddWidget("TeamIndicators")
HudController:AddWidget("ObjectiveIndicators")

local ScoreUISettings = Moon.ScoreUISettings.Get()
ScoreUISettings.MatchDescription = tostring(WinningKillCount) .. " kills to win" 
ScoreUISettings.WinLimit = WinningKillCount
ScoreUISettings.MatchName = "Team Death Match"
ScoreUISettings.DisplayPlayerName = false
ScoreUISettings.ShowTeamName = true
ScoreUISettings.ShowPlace = false
ScoreUISettings.IsTeamMatch = true

MS.Utility.Log("TDM.luau Finished")