local Inventory = require("Inventory")
local GunCycle = require("GunGame_WeaponCycles")
local SpawnFilters = require("SpawnFilters")
local Tagging = require("Tagging")
local Outfits = require("Outfits")
local MidnightUtility = require("MidnightUtility")
local Audio = require("Audio")
local Effects = require("Effects")

--Globals

--Number of times a player can respawns
WeaponCycle = {}
LeaderScore = 0
CatchupDif = 5
CustomStatName = "GunIndex"
LeadingPlayer = nil
--End Globals

--Configure Game Mode
local GameMode = Moon.GameMode.First()
local MatchSize = GameMode:MatchSize()
LevelVariatonTag = nil


local ScriptTuner = Moon.ScriptTuner.GetOrMake()


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

--Time between automatic respawns
GameMode.RespawnDelay = ScriptTuner:GetInt("Spawn/RespawnDelay", 1)
GameMode.AutomaticRespawn = true

local LootRules = Moon.MatchLootRules.Get()
LootRules.EnableLoot = ScriptTuner:GetBool("Loot/Enabled", false)
LootRules.EnableDeathbags = ScriptTuner:GetBool("Loot/Deathbags", false)
LootRules.DeathBagLifetime = ScriptTuner:GetInt("Loot/DeathbagLifetimes", 60)
LootRules.RespawnLoot = ScriptTuner:GetBool("Loot/Respawn", false)
LootRules.ContainerRespawnTime = ScriptTuner:GetInt("Loot/ContainerDelay", 3) * 60
LootRules.PickupRespawnTime = ScriptTuner:GetInt("Loot/PickupDelay", 1) * 60



local NumberOfPlayers = 0

local MessageController = Moon.MessageController.Get()

local PlayersCatchingUp = MidnightUtility.MidnightTable.New()

GameMode.OnLogin:Connect(function (Player)
	Effects.AddHealthRegen(Player)
	GunCycle.TryGrantCycleWeapon(Player, WeaponCycle, true)

	PlayersCatchingUp[Player] = false

	if PlayerBotManager:IsPlayerABot(Player) == false then
		NumberOfPlayers = NumberOfPlayers + 1
	end

	Player.OnKill:Connect(function(Victim)
		Player:GetEquipment():ClearInventory()
		Player:GetBackpack():ClearInventory()
		
		local NextIndex = GunCycle.GetCurrentWeaponIndex(Player) + 1
		local CurrentIndex = 0

		if NextIndex <= LeaderScore - CatchupDif then
			CurrentIndex =  GunCycle.TryGrantCycleWeapon(Player, WeaponCycleBuffed, true)
		else
			CurrentIndex = GunCycle.TryGrantCycleWeapon(Player, WeaponCycle, true)

			if PlayersCatchingUp[Player] == true then
				PlayersCatchingUp[Player] = false
				MessageController:SendMessage({Player}, "You are catching back up", 5)
			end
		end

		if CurrentIndex > #WeaponCycle then
			GameMode:EndMatch(Player)
			Audio.PlayGlobalSound({Sound=Audio.Sound.LargeEnderOne})
			Moon.HudController.Get():AddWidget("MatchStats")	
		end

		Moon.PlayerStats.SetCustomStatValue(Player, CustomStatName, CurrentIndex - 1)

		if CurrentIndex > LeaderScore then
			LeaderScore = CurrentIndex
			LeadingPlayer = Player
		end
	end)

	Player.OnKilled:Connect(function(Killer)
		if Killer:GetName() == Player:GetName() then
			Player:GetEquipment():ClearInventory()
			Player:GetBackpack():ClearInventory()
			Moon.PlayerStats.SetCustomStatValue(Player, CustomStatName, GunCycle.TryGrantCycleWeapon(Player, WeaponCycle, false) - 1)
		end
	end)

	if NumberOfPlayers + NumberOfPlayersBots > 30 then
		PlayerBotManager:RemoveRandomPlayerBot()
	end
end)

GameMode:SetInventoryImportEnabled(false)
GameMode:SetInventoryExportEnabled(false)

GameMode.ShouldRespawn:Connect(function (Player)
	return true
end)

GameMode.GetPawnClass:Connect(function(Player)
	return "Default"
end)

function ApplyCatchup(Player, Index)
	Player:GetEquipment():ClearInventory()
	Player:GetBackpack():ClearInventory()

	MessageController:SendMessage({Player}, "You are falling behind", 5)
	Inventory.GrantWeapon(Player, WeaponCycleBuffed[Index], true, true)

	PlayersCatchingUp[Player] = true
end


GameMode.OnRespawn:Connect(function(Player)
	local CurrentIndex = GunCycle.GetCurrentWeaponIndex(Player) 

	if CurrentIndex <= LeaderScore - CatchupDif then
		ApplyCatchup(Player, CurrentIndex)
	end

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

MatchTime = ScriptTuner:GetInt("GameRules/TimeLimit", 20) * 60
GameMode:SetMatchClock(MatchTime)
MS.Utility.SetTimer(function ()
	GameMode:EndMatch(LeadingPlayer)
	Audio.PlayGlobalSound({Sound=Audio.Sound.LargeEnderOne})
	Moon.HudController.Get():AddWidget("MatchStats")
end, MatchTime)


local Sniper = { Weapon="SniperRifle", Parts={"8xPTS-2"}}
local AssaultRifle = { Weapon="AssaultRifle", Parts={}}
local Shotgun = { Weapon="RangeShotgun", Parts={}}
local HeavyPistol = { Weapon="HeavyPistol", Parts={}}
local DeepFreezeSMG = { Weapon="DeepFreezeSMG", Parts={}}
local DeepFreezeShotgun = { Weapon="DeepFreezeShotgun", Parts={}}
local AutoPistol = { Weapon="AutoPistol", Parts={}}
local LMG = { Weapon="LMG", Parts={}}
local BurstPistol = { Weapon="BurstPistol", Parts={}}
local SemiPistol = { Weapon="SemiPistol", Parts={}}
local DMR = { Weapon="DMR", Parts={}}
local DoubleBarrel = { Weapon="DoubleBarrel", Parts={}}
local Knife = { Weapon="Knife", Parts={}}

local SniperBuffed = { Weapon="SniperRifle", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "WeaponChip", "8xPTS-2"}}
local AssaultRifleBuffed = { Weapon="AssaultRifle", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "3xReflex-1", "WeaponChip"}}
local ShotgunBuffed = { Weapon="RangeShotgun", Parts={"BarrelIV", "GripIV", "StockIV", "2xHolo-1", "BlueLaser", "WeaponChip"}}
local HeavyPistolBuffed = { Weapon="HeavyPistol", Parts={"BarrelIV", "GripIV", "BlueLaser", "3xReflex-1", "WeaponChip"}}
local DeepFreezeSMGBuffed = { Weapon="DeepFreezeSMG", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "2xHolo-1", "WeaponChip"}}
local DeepFreezeShotgunBuffed = { Weapon="DeepFreezeShotgun", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "2xHolo-1", "WeaponChip"}}
local AutoPistolBuffed = { Weapon="AutoPistol", Parts={"BarrelIV", "GripIV", "BlueLaser", "3xReflex-1", "WeaponChip"}}
local LMGBuffed = { Weapon="LMG", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "3xReflex-1", "WeaponChip"}}
local BurstPistolBuffed = { Weapon="BurstPistol", Parts={"BarrelIV", "GripIV", "BlueLaser", "2xHolo-1", "WeaponChip"}}
local SemiPistolBuffed = { Weapon="SemiPistol", Parts={"BarrelIV", "GripIV", "BlueLaser", "2xHolo-1", "WeaponChip"}}
local DMRBuffed = { Weapon="DMR", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "4xPTS-1", "WeaponChip"}}
local DoubleBarrelBuffed = { Weapon="DoubleBarrel", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "WeaponChip"}}
local KnifeBuffed = { Weapon="Knife", Parts={}}

WeaponCycle = {SemiPistol, AssaultRifle, HeavyPistol, DeepFreezeSMG, DeepFreezeShotgun, AutoPistol, LMG, DMR, DoubleBarrel, BurstPistol, Shotgun, Sniper, Knife}
WeaponCycleBuffed = {SemiPistolBuffed, AssaultRifleBuffed, HeavyPistolBuffed, DeepFreezeSMGBuffed, DeepFreezeShotgunBuffed, AutoPistolBuffed, LMGBuffed, DMRBuffed, DoubleBarrelBuffed, BurstPistolBuffed, ShotgunBuffed, SniperBuffed, KnifeBuffed}

Moon.PlayerStats.SetDamageTrackingDuration(15)

local HudController = Moon.HudController.Get()
HudController:AddWidget("ScoreBug")

local ScoreUISettings = Moon.ScoreUISettings.Get()
ScoreUISettings.StatName = CustomStatName
ScoreUISettings.MatchDescription = "Get a kill with each weapon"
ScoreUISettings.MatchName = "Arsenal" 
ScoreUISettings.WinLimit = table.getn(WeaponCycle)
ScoreUISettings.DisplayPlayerName = true
ScoreUISettings.ShowPlace = false

MS.Utility.Log("GunGame.luau Finished")