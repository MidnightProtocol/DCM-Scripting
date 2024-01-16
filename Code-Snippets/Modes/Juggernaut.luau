
local Inventory = require("Modules/Inventory")
local SpawnFilters = require("Modules/SpawnFilters")
local Tagging = require("Modules/Tagging")
local MidnightUtility = require("Modules/MidnightUtility")
local Outfits = require("Modules/Outfits")
local Audio = require("Modules/Audio")
local Effects = require("Modules/Effects")

--Globals
--Configure Game Mode
local GameMode = Moon.GameMode.First()
local MatchSize = GameMode:MatchSize()
LevelVariatonTag = nil

if MatchSize <= 6 then
    LevelVariatonTag = "Moon.LevelVariation.Small"
elseif MatchSize <= 18 then
    LevelVariatonTag = "Moon.LevelVariation.Medium"
else
    LevelVariatonTag = nil
end

if LevelVariatonTag ~= nil then
    Moon.LevelVariation.LoadLevelVariation(LevelVariatonTag)
end

local ScriptTuner = Moon.ScriptTuner.GetOrMake()

GameMode.RespawnDelay = ScriptTuner:GetInt("Spawn/RespawnDelay", 5)
GameMode.AutomaticRespawn = true

local LootRules = Moon.MatchLootRules.Get()
LootRules.EnableLoot = ScriptTuner:GetBool("Loot/Enabled", true)
LootRules.EnableDeathbags = ScriptTuner:GetBool("Loot/Deathbags", false)
LootRules.DeathBagLifetime = ScriptTuner:GetInt("Loot/DeathbagLifetimes", 60)
LootRules.RespawnLoot = ScriptTuner:GetBool("Loot/Respawn", true)
LootRules.ContainerRespawnTime = ScriptTuner:GetInt("Loot/ContainerDelay", 3) * 60
LootRules.PickupRespawnTime = ScriptTuner:GetInt("Loot/PickupDelay", 1) * 60

local Players = MidnightUtility.MidnightTable.New()

-- Team Settings
local TeamSettings = Moon.Teams.Settings()
TeamSettings.AutoCreateTeams = false
TeamSettings.UseSquadColors = false

TeamJuggernaut = Moon.Teams.GetOrMakeTeam("Juggernaut")
TeamNormal = Moon.Teams.GetOrMakeTeam("Normal")

--Globals
local CurrentJuggernaut = nil

local ScoreToWin = ScriptTuner:GetInt("GameRules/ScoreLimit", 1500)
local PointsPerKill = ScriptTuner:GetInt("GameRules/PointsPerKill", 100)
local ScoreStateName = "Enforcer"

local SetJuggernautTimerHandle = nil
local TimeToNewJuggernaut = 5

local CurrentJuggernuatObjective = nil

local EnabledSlowZones = ScriptTuner:GetBool("GameRules/EnableSlowZones", true)
local MaxSlowZones = 4

RoundTime = ScriptTuner:GetInt("GameRules/TimeLimit", 20) * 60

--Create an effect with additive modifiers
Juggernaut = Moon.GameplayEffect.CreateEffect("Additive", 0)
Juggernaut:SetMagnitude("MaxHealth", ScriptTuner:GetInt("Health/JuggernautHealth", 300))
Juggernaut:SetMagnitude("Armor", ScriptTuner:GetInt("Health/JuggernautArmor", 60))
Juggernaut:SetMagnitude("MoveSpeed", -ScriptTuner:GetInt("GameRules/JuggernautMovement", 100))

SlowZoneEffect = Moon.GameplayEffect.CreateEffect("Additive", 0)
SlowZoneEffect:SetMagnitude("MoveSpeed", -ScriptTuner:GetInt("GameRules/SlowZoneMovement", 150))

--End Globals

--Weapons
local LMG = { 
	Weapon="LMG", 
	Parts={"BarrelIV", "GripIV", "StockIV", "2xHolo-1"}
}

local MessageController = Moon.MessageController.Get();
local GlobalObjectives = Moon.ObjectiveSettings.Get()

local SlowZones = {}

local MaxSpawnSize = 10
local MinSpawnSize = 2

local MinSpawnInterval = 10
local MaxSpawnInterval = 45

local CurrentJuggernautTimer = nil

local PlayerSlowZoneTracker = MidnightUtility.MidnightTable.New()

function SpawnSlowZone()
	if CurrentJuggernaut ~= nil then
		local CurrentScore = Moon.PlayerStats.GetCustomStatValue(CurrentJuggernaut, ScoreStateName)

		local ScaleRatio = (ScoreToWin-CurrentScore)/ScoreToWin

		local Size = MinSpawnSize + (ScaleRatio * (MaxSpawnSize - MinSpawnSize))

		local TriggerScale = {X=Size, Y=Size, Z=2.5}
		local TriggerRotation = {Yaw=60, Pitch=0, Roll=0}	
		local Loc = CurrentJuggernaut:GetLocation()
		Loc.Z = Loc.Z - 70
		local Zone = Moon.Trigger.SpawnTrigger(Loc, TriggerScale, TriggerRotation)
		Zone:SetColor({R=0,G=0.3,B=0,A=1})
		table.insert(SlowZones, Zone)

		Zone.OnPlayerOverlapBegin:Connect(function (Player)
			if CurrentJuggernaut ~= nil and Player ~= nil and Player:GetName() ~= CurrentJuggernaut:GetName() then
				if PlayerSlowZoneTracker[Player] == nil then
					PlayerSlowZoneTracker[Player] = {Count=0,EffectHandle=nil}
				end

				PlayerSlowZoneTracker[Player].Count = PlayerSlowZoneTracker[Player].Count + 1

				if PlayerSlowZoneTracker[Player].Count == 1 then
					PlayerSlowZoneTracker[Player].EffectHandle = Moon.GameplayEffect.ApplyEffect(Player, SlowZoneEffect)
				end
			end
		end)

		Zone.OnPlayerOverlapEnd:Connect(function (Player)
			if PlayerSlowZoneTracker[Player] ~= nil then
				PlayerSlowZoneTracker[Player].Count = math.max(0, PlayerSlowZoneTracker[Player].Count - 1)
				
				if PlayerSlowZoneTracker[Player].Count == 0 then
					Moon.GameplayEffect.RemoveEffect(Player, PlayerSlowZoneTracker[Player].EffectHandle)
				end
			end
		end)

		local NextTime = MinSpawnInterval + ((1-ScaleRatio) * (MaxSpawnInterval - MinSpawnInterval))

		if CurrentJuggernautTimer ~= nil then
			MS.Utility.ClearTimer(CurrentJuggernautTimer)
		end
		
		CurrentJuggernautTimer = MS.Utility.SetTimer(SpawnSlowZone, NextTime, false)
	end

	if #SlowZones >= MaxSlowZones then
		ToDestroy = table.remove(SlowZones, 1)
		ToDestroy:Destroy()
	end
end

function InitSpawnSlowZone()
	SpawnSlowZone()
end

function SetJuggernaut(Player)
	if CurrentJuggernuatObjective ~= nil then
		GlobalObjectives:RemoveObjective(CurrentJuggernuatObjective)
	end
	
	MessageController:ClearMessage({CurrentJuggernaut})

	CurrentJuggernaut = Player

	if CurrentJuggernautTimer ~= nil then
		MS.Utility.ClearTimer(CurrentJuggernautTimer)
	end
	
	if SetJuggernautTimerHandle ~= nil then
		MS.Utility.ClearTimer(SetJuggernautTimerHandle)
	end

	if PlayerSlowZoneTracker[Player] ~= nil and PlayerSlowZoneTracker[Player].Count > 0 then
		PlayerSlowZoneTracker[Player].Count = 0
		Moon.GameplayEffect.RemoveEffect(Player, PlayerSlowZoneTracker[Player].EffectHandle)
	end

	
	local NormalTeam = TeamNormal:GetTeamMembers()

	local IndexToRemove = 0
	
	for i = 1, #NormalTeam do
		if NormalTeam[i]:GetName() == CurrentJuggernaut:GetName() then
			IndexToRemove = i
			break
		end
	end

	if IndexToRemove > 0 then
		table.remove(NormalTeam, IndexToRemove)
	end

	MessageController:SendMessage(NormalTeam, "New Enforcer In...", TimeToNewJuggernaut, true)

	MessageController:SendMessage({CurrentJuggernaut}, "You Killed The Enforcer", 2)

	MS.Utility.SetTimer(function()
		MessageController:SendMessage({CurrentJuggernaut}, "You Are The Next Enforcer In...", TimeToNewJuggernaut - 1, true)
	end, TimeToNewJuggernaut - 3)


	SetJuggernautTimerHandle = MS.Utility.SetTimer(function ()
		Player:GetBackpack():ClearInventory()
		Player:GetEquipment():ClearInventory()

		Audio.PlayGlobalSound({Sound=Audio.Sound.TechStingerThree, Location=CurrentJuggernaut:GetLocation(), VolumeMultiplier=0.5})

		Moon.GameplayEffect.ResetAttributeBaseValue(CurrentJuggernaut, "Base", "Health")
		Moon.GameplayEffect.ApplyEffect(CurrentJuggernaut, Juggernaut)

		TeamJuggernaut:AddPlayer(Player)
		CurrentJuggernuatObjective = GlobalObjectives:AddObjective({TargetActor=Player, IndicatorType="Indicator.Objective.Enforcer", IndicatorColor={R=1,B=1,G=1,A=1}, IndicatorOffset={X=0,Y=0,Z=20}})

		Player:SetScale(1.15)

		Player:SetInfiniteClip(true)

		Inventory.GrantWeapon(Player, LMG, true, true)
		Player:GetEquipment():AddItem("FragGrenade")
		Player:GetEquipment():AddItem("SmokeGrenade")

		MessageController:SendMessage({CurrentJuggernaut}, "You are the Enforcer", 0)
		Outfits.SetOutfit(Player, Outfits.Outfits.CleanersGuard)

		Player:AddTag("Interaction.Block.Loot")
		Player:AddTag("Interaction.Block.Lifelink")
		Effects.RemoveHealthRegen(Player)

		if EnabledSlowZones == true then
			InitSpawnSlowZone()
		end

	end, TimeToNewJuggernaut)
end

--Weapons
local SMG = { 
	Weapon="SMG", 
	Parts={"3xReflex-1", "BarrelIV", "GripIV", "StockIV"}
}

function InitPlayer(Player)
	Player:GetBackpack():ClearInventory()
	Player:GetEquipment():ClearInventory()

	Inventory.GrantWeapon(Player, SMG, true, true)
	Player:GetEquipment():AddItem("Thruster")

	Effects.AddHealthRegen(Player)

	Player:RemoveTag("Interaction.Block.Loot")
	Player:RemoveTag("Interaction.Block.Lifelink")
end

GameMode.OnLogout:Connect(function (Player)
	table.remove(Players, MidnightUtility.TableFind(Players, Player))
	if CurrentJuggernaut ~= nil and Player:GetName() == CurrentJuggernaut:GetName() and #Players > 0 then
		MidnightUtility.Shuffle(Players)
		SetJuggernaut(Players[1])
	end
end)

GameMode.OnLogin:Connect(function (Player)
	table.insert(Players, Player)
	Player.OnKill:Connect(function(Victim)

		if CurrentJuggernaut:GetName() == Player:GetName() and Victim:GetName() ~= CurrentJuggernaut:GetName() then
			Moon.PlayerStats.AddCustomStatValue(CurrentJuggernaut, ScoreStateName, PointsPerKill)
	
			if Moon.PlayerStats.GetCustomStatValue(CurrentJuggernaut, ScoreStateName) >= ScoreToWin then
				GameMode:EndMatch(Player)
				Audio.PlayGlobalSound({Sound=Audio.Sound.LargeEnderOne})
				Moon.HudController.Get():AddWidget("MatchStats")
			end
		end
	end)

	Player.OnKilled:Connect(function(Killer)
		if Killer:GetName() == Player:GetName() and CurrentJuggernaut:GetName() == Player:GetName() then
			Moon.Location.RemoveAllLocationIndicators(Player)
			TeamNormal:AddPlayer(Player)

			if #Players > 1 then 
				MidnightUtility.Shuffle(Players)
				for i = 1, #Players do
					if Players[i]:GetName() ~= Player:GetName() then 
						SetJuggernaut(Players[i])
					end
				end
			end

		elseif CurrentJuggernaut:GetName() == Player:GetName() then
			Moon.Location.RemoveAllLocationIndicators(Player)
			TeamNormal:AddPlayer(Player)
			SetJuggernaut(Killer)	
		end
	end)

end)

GameMode.OnRespawn:Connect(function (Player)
	if CurrentJuggernaut == nil then
		SetJuggernaut(Player)
	else
		TeamNormal:AddPlayer(Player)
		InitPlayer(Player)
	end

	if PlayerSlowZoneTracker[Player] ~= nil and PlayerSlowZoneTracker[Player].Count > 0 then
		PlayerSlowZoneTracker[Player].Count = 0
	end

end)

GameMode.ShouldRespawn:Connect(function (Player)
	return true
end)

GameMode.GetPawnClass:Connect(function(Player)
	return "Default"
end)

GameMode:AddPlayerStartFilter(SpawnFilters.MediumEnemyDistanceFilter)
GameMode:AddPlayerStartFilter(function (Player, PlayerStarts)
	local OutPlayerStarts = Tagging.FilterByTag(PlayerStarts, "Spawn.FFA")
	
	if #OutPlayerStarts == 0 then
		MS.Utility.Log("Lua player filter found no valid player starts. Returning full array")
		return PlayerStarts
	else
		return OutPlayerStarts
	end
end)

GameMode:SetMatchClock(RoundTime)
MS.Utility.SetTimer(function ()
	local WinningPlayer = nil
	local WinningScore = -1

	for i = 1, #Players do
		local PlayerScore = Moon.PlayerStats.GetCustomStatValue(Players[i], ScoreStateName)
		if PlayerScore > WinningScore then
			WinningScore = PlayerScore
			WinningPlayer = Players[i]
		end
	end
	
	GameMode:EndMatch({WinningPlayer})
	Moon.HudController.Get():AddWidget("MatchStats")
end, RoundTime)

Moon.PlayerStats.SetDamageTrackingDuration(15)

local HudController = Moon.HudController.Get()
HudController:AddWidget("ScoreBug")
HudController:AddWidget("ObjectiveIndicators")

local ScoreUISettings = Moon.ScoreUISettings.Get()
ScoreUISettings.StatName = ScoreStateName
ScoreUISettings:SetMatchDescription(tostring(ScoreToWin) .. " points to win")
ScoreUISettings:SetMatchName("Enforcer") 
ScoreUISettings.WinLimit = ScoreToWin
ScoreUISettings.DisplayPlayerName = true
ScoreUISettings.ShowPlace = true
ScoreUISettings.ShowClock = true

local Columns = ScoreUISettings:GetMatchStatColumns()
table.insert(Columns, 1, ScoreStateName)
ScoreUISettings:SetMatchStatColumns(Columns)

MS.Utility.Log("Juggernaut.luau Finished")