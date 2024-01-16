
local Inventory = require("Modules/Inventory")
local SpawnFilters = require("Modules/SpawnFilters")
local Tagging = require("Modules/Tagging")
local MidnightUtility = require("Modules/MidnightUtility")
local Outfits = require("Modules/Outfits")
local Audio = require("Modules/Audio")

--Globals
local GameMode = Moon.GameMode.First()
local ScriptTuner = Moon.ScriptTuner.GetOrMake()

GameMode.RespawnDelay = ScriptTuner:GetInt("Spawn/RespawnDelay", 5)
GameMode.AutomaticRespawn = true

local LootRules = Moon.MatchLootRules.Get()

LootRules.EnableLoot = true
LootRules.ContainerRespawnTime = 3 * 60
LootRules.PickupRespawnTime = 1 * 60
LootRules.EnableDeathbags = false

local Players = MidnightUtility.MidnightTable.New()

-- Team Settings
local TeamSettings = Moon.Teams.Settings()
TeamSettings.AutoCreateTeams = false
TeamSettings.UseSquadColors = false

TeamJuggernaut = Moon.Teams.GetOrMakeTeam("Juggernaut")
TeamNormal = Moon.Teams.GetOrMakeTeam("Normal")

--Globals
local CurrentJuggernaut = nil

local ScoreToWin = ScriptTuner:GetInt("GameRules/ScoreLimit", 1000)
local PointsPerKill = ScriptTuner:GetInt("GameRules/PointsPerKill", 100)
local ScoreStateName = "Juggernaut"

local SetJuggernautTimerHandle = nil
local TimeToNewJuggernaut = 5

local CurrentJuggernuatObjective = nil

--Create an effect with additive modifiers
Juggernaut = Moon.GameplayEffect.CreateEffect("Additive", 0)
Juggernaut:SetMagnitude("MaxHealth", ScriptTuner:GetInt("Health/JuggernautHealth", 300))
Juggernaut:SetMagnitude("Armor", ScriptTuner:GetInt("Health/JuggernautArmor", 60))
Juggernaut:SetMagnitude("MoveSpeed", -ScriptTuner:GetInt("GameRules/JuggernautMovement", 100))

--End Globals

--Weapons
local LMG = { 
	Weapon="LMG", 
	Parts={"3xReflex-1", "WeaponChip", "ExtendedRifleClip"}
}

local MessageController = Moon.MessageController.Get();
local GlobalObjectives = Moon.ObjectiveSettings.Get()

function SetJuggernaut(Player)

	if CurrentJuggernuatObjective ~= nil then
		GlobalObjectives:RemoveObjective(CurrentJuggernuatObjective)
	end
	
	MessageController:ClearMessage({CurrentJuggernaut})

	CurrentJuggernaut = Player

	if SetJuggernautTimerHandle ~= nil then
		MS.Utility.ClearTimer(SetJuggernautTimerHandle)
	end

	MessageController:SendMessageToAll("New Juggernaut in...", TimeToNewJuggernaut, true)

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
		
	end, TimeToNewJuggernaut)
end

--Weapons
local AssaultRifle = { 
	Weapon="AssaultRifle", 
	Parts={"3xReflex-1", "ExtendedRifleClip"}
}

function InitPlayer(Player)
	Player:GetBackpack():ClearInventory()
	Player:GetEquipment():ClearInventory()

	Inventory.GrantWeapon(Player, AssaultRifle, true, true)
	Player:GetEquipment():AddItem("Thruster")

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

Moon.PlayerStats.SetDamageTrackingDuration(15)

local HudController = Moon.HudController.Get()
HudController:AddWidget("ScoreBug")
HudController:AddWidget("ObjectiveIndicators")

local ScoreUISettings = Moon.ScoreUISettings.Get()
ScoreUISettings.StatName = ScoreStateName
ScoreUISettings.MatchDescription = tostring(ScoreToWin) .. " points to win"
ScoreUISettings.MatchName = "Enforcer" 
ScoreUISettings.WinLimit = ScoreToWin
ScoreUISettings.DisplayPlayerName = false
ScoreUISettings.ShowPlace = true
ScoreUISettings.IsTeamMatch = false
ScoreUISettings.ShowTeamName = true

local Columns = ScoreUISettings.MatchStatColumns
table.insert(Columns, 1, ScoreStateName)
ScoreUISettings.MatchStatColumns = Columns

MS.Utility.Log("Juggernaut.luau Finished")