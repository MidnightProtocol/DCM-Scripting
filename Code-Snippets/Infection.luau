local Inventory = require("Inventory")
local SpawnFilters = require("SpawnFilters")
local Effects = require("Effects")
local MidnightUtility = require("MidnightUtility")
local Math = require("Math")
local Rounds = require("Rounds")
local Outfits = require("Outfits")
local Audio = require("Audio")

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

local MessageController = Moon.MessageController.Get();
local ScriptTuner = Moon.ScriptTuner.GetOrMake()

--Time between automatic respawns
GameMode.RespawnDelay = ScriptTuner:GetInt("Spawn/RespawnDelay", 1)
GameMode.AutomaticRespawn = true

GameMode:SetInventoryImportEnabled(false)
GameMode:SetInventoryExportEnabled(false)

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

--Teams
local Infected = Moon.Teams.GetOrMakeTeam("Infected")
local Human = Moon.Teams.GetOrMakeTeam("Human")

--Spawn Point Tracking
local SpawnPoints = {}

--Effects
--Create an effect with additive modifiers
InfectedEffect = Moon.GameplayEffect.CreateEffect("Additive", 0)
InfectedEffect:SetMagnitude("MoveSpeed", ScriptTuner:GetInt("GameRules/InfectedMovement", 100))
InfectedEffect:SetMagnitude("MaxHealth", ScriptTuner:GetInt("Health/InfectedAdditionalHealth", 50))

HumanEffect = Moon.GameplayEffect.CreateEffect("Additive", 0)
HumanEffect:SetMagnitude("Armor", -195)

LastManStandingEffect = Moon.GameplayEffect.CreateEffect("Additive", 0)
LastManStandingEffect:SetMagnitude("MaxHealth", ScriptTuner:GetInt("Health/FinalSurvivorAdditionalHealth", 100))
LastManStandingEffect:SetMagnitude("MoveSpeed", ScriptTuner:GetInt("GameRules/FinalSurvivorMovement", 100))

--LUA GLOBALS--
CurrentInfectedCount = 0
HumansSinceLastInfected = 0
HumansPerInfected = 10

StartingAmmo = 15

local HumanPingTime = 3.0 * 60.0
local HumanPingInterval = 10

local HumanPingTimerHandle = nil
local DisableHumanSpawnsHandle = nil

local TimeToTurnOffHumanSpawns = 2.0 * 60.0
local AllowHumanSpawns = true

local CustomStatName = "Points"

local PointsForHumanKill = ScriptTuner:GetInt("GameRules/HumanKillPoints", 20)
local PointsForInfectedKill = ScriptTuner:GetInt("GameRules/InfectedKillPoints", 20)
local PointsForRoundWin = ScriptTuner:GetInt("GameRules/PointsPerRoundWin", 20)

local ScoreBuckets = {}
ScoreBuckets[20] = 10
ScoreBuckets[10] = 20
ScoreBuckets[5] = 30
ScoreBuckets[1] = 50

local InfectedSounds = {{Sound = "Audio.Character.Infected", PitchMultiplier=0.5, Attenuation=Audio.Attenuation.Medium}, {Sound = "Audio.Character.InfectedOne", PitchMultiplier=0.8, Attenuation=Audio.Attenuation.Medium}, 
							{Sound = "Audio.Character.InfectedTwo", PitchMultiplier=0.5, Attenuation=Audio.Attenuation.Medium}, {Sound = "Audio.Character.InfectedThree", PitchMultiplier=0.7, Attenuation=Audio.Attenuation.Medium}}
local InfectedSoundIntervalMax = 16
local InfectedSoundIntervalMin = 7

local Players = MidnightUtility.MidnightTable.New()

IntroMessageUp = true
--END LUA GLOBALS--

function DisableHumanSpawns()
	AllowHumanSpawns = false
end

local DoubleBarrel = 
{
	Weapon = "DoubleBarrel",
	Parts={}
}

local Knife = { 
	Weapon="Knife", 
	Parts={}
}

function InitHumanPlayer(Player)
	Moon.GameplayEffect.ApplyEffect(Player, HumanEffect)
	Player:GetEquipment():AddItem("LargeBackpack")
	
	Inventory.GrantWeapon(Player, DoubleBarrel, true, true)
	Inventory.GrantWeapon(Player, Knife, true, false)
	
	for i = 1, StartingAmmo do
		Player:GetBackpack():AddItem("ShotgunAmmo")
	end

	Effects.AddHealthRegen(Player)

	Moon.HudController.GetForPlayer(Player):RemoveWidget("InfectedScreenEffect")

	Player:RemoveTag("Interaction.Block.Loot")
	Player:RemoveTag("Interaction.Block.Lifelink")
end

function InitInfectedPlayer(Player)
	Moon.GameplayEffect.ApplyEffect(Player, InfectedEffect)
	Inventory.GrantWeapon(Player, Knife, true, true)
	
	Effects.RemoveHealthRegen(Player)

	Player:AddTag("Interaction.Block.Loot")
	Player:AddTag("Interaction.Block.Lifelink")

	Outfits.SetOutfit(Player, Outfits.Outfits.Infected)
	Moon.HudController.GetForPlayer(Player):AddWidget("InfectedScreenEffect")

	DelayToDisplay = 0.5
	if IntroMessageUp then
		DelayToDisplay = 8
	end

	MS.Utility.SetTimer(function()
		MessageController:SendMessage({Player}, "You Are Infected", 10)
	end, DelayToDisplay)
end

function InitLastManStanding(Player)
	Moon.GameplayEffect.ResetAttributeBaseValue(Player, "Base", "Health")
	Moon.GameplayEffect.ResetAttributeBaseValue(Player, "Base", "Armor")
	Moon.GameplayEffect.ApplyEffect(Player, LastManStandingEffect)

	Player:SetInfiniteClip(true)
	Player:SetInfiniteAmmo(true)

	MessageController:SendMessage({Player}, "Final Survivor", 0)
end

function CheckForHumanScoring()
	local HumansLeft = Human:Size() 
	local ScoreBucket = ScoreBuckets[HumansLeft]
	if ScoreBucket ~= nil then
		local HumanTeamPlayers = Human:GetTeamMembers()
		for i = 1, #HumanTeamPlayers do
			Moon.PlayerStats.AddCustomStatValue(HumanTeamPlayers[i], CustomStatName, ScoreBucket)
		end

		if HumansLeft > 1 then
			MessageController:SendMessageToAll(tostring(HumansLeft) .. " Survivors Left", 10)
		else
			MessageController:SendMessageToAll(tostring(HumansLeft) .. " Survivor Left", 10)
		end
	end
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

	if CurrentInfectedCount == 0 or AllowHumanSpawns == false or HumansSinceLastInfected == HumansPerInfected then 
		Infected:AddPlayer(Player)
		CurrentInfectedCount = CurrentInfectedCount + 1
		HumansSinceLastInfected = 0
	else
		Human:AddPlayer(Player)
		HumansSinceLastInfected = HumansSinceLastInfected + 1
	end
	
	Player:SetInfiniteAmmo(false)

	MS.Utility.SetTimer(function()
		Audio.PlaySoundForPlayer({Sound = "Audio.Creator.InfectionStart"}, Player)
		MessageController:SendMessage({Player}, "Infection", 5)
		MS.Utility.SetTimer(function()
			IntroMessageUp = false
		end, 5)
	end, 4)

	Player.OnKill:Connect(function(Victim)
		if Human:HasPlayer(Victim) then
			Moon.PlayerStats.AddCustomStatValue(Player, CustomStatName, PointsForHumanKill)
		elseif Infected:HasPlayer(Victim) then
			Moon.PlayerStats.AddCustomStatValue(Player, CustomStatName, PointsForInfectedKill)
		end
	end)
	
	Player.OnKilled:Connect(function (Killer)
		--Delete any old spawn point first
		SpawnPoints[Player:GetName()] = nil

		if Human:HasPlayer(Player) then
			Human:RemovePlayer(Player)
			
			CheckForHumanScoring()

			if Human:Size() == 1 then
				InitLastManStanding(Human:GetTeamMembers()[1])
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

	Player:SetInfiniteClip(false)
	Player:SetInfiniteAmmo(false)

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

function PlayInfectedSound()
	local InfectedMembers = Infected:GetTeamMembers()
	if #InfectedMembers > 0 then
		local RandomSound = InfectedSounds[math.random(1, #InfectedSounds)]
		RandomSound.Location = InfectedMembers[math.random(1, #InfectedMembers)]:GetLocation()
		Audio.PlaySoundForPlayers(RandomSound, Human:GetTeamMembers())
	end
end


MS.Utility.SetTimer(function ()
	MS.Utility.SetTimer(PlayInfectedSound, math.random(0, InfectedSoundIntervalMax - InfectedSoundIntervalMin))
end, InfectedSoundIntervalMin, true)

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
	HumansSinceLastInfected = 0

	MidnightUtility.Shuffle(Players)

	for i = 1, #Players do
		if CurrentInfectedCount == 0 or HumansSinceLastInfected == HumansPerInfected then
			Infected:AddPlayer(Players[i])
			CurrentInfectedCount = CurrentInfectedCount + 1
			HumansSinceLastInfected = 0
		else
			Human:AddPlayer(Players[i])
			HumansSinceLastInfected = HumansSinceLastInfected + 1
		end

		Players[i]:Reset()
	end

	
	LootRules:ClearAllDeathBags()

	DisableHumanSpawnsHandle = MS.Utility.SetTimer(DisableHumanSpawns, TimeToTurnOffHumanSpawns)
	HumanPingTimerHandle = MS.Utility.SetTimer(HumanPing, HumanPingInterval, true, HumanPingTime)
	ScoreUISettings.MatchDescription = "Humans Survive \nInfected Kill."
end)

Rounds.SetOnRoundEndMessage(function ()
	print("Lua test")
	if Human:Size() == 0 then

		MS.Utility.SetTimer(function()
			MessageController:SendMessageToAll("All Survivors Have Been Infected", Rounds.EndRoundMessageTime - 3)
		end, 3)

		return "Round Ended"
	else
		
		MS.Utility.SetTimer(function()
			MessageController:SendMessageToAll("Survivors Lived", Rounds.EndRoundMessageTime - 3)
		end, 3)

		return "Round Ended"
	end
end)

Rounds.SetOnRoundEnd(function()
	
	Moon.AudioController.PlayGlobalSound({Sound=Audio.Sound.LargeObjectiveThree, VolumeMultiplier=0.6})

	if HumanPingTimerHandle ~= nil then
		MS.Utility.ClearTimer(HumanPingTimerHandle)
	end

	if DisableHumanSpawnsHandle ~= nil then
		MS.Utility.ClearTimer(DisableHumanSpawnsHandle)
	end

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