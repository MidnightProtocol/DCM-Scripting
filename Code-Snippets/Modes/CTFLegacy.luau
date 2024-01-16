local Inventory = require("Modules/Inventory")
local SpawnFilters = require("Modules/SpawnFilters")
local Tagging = require("Modules/Tagging")
local Audio = require("Modules/Audio")
local Effects = require("Modules/Effects")
local Outfits = require("Modules/Outfits")

--Configure Game Mode
local GameMode = Moon.GameMode.First()

local MatchSize = GameMode:MatchSize()

LevelVariatonTag = nil
BlueFlagSpawnTag = "Top.SideB"
RedFlagSpawnTag = "Top.SideA"

if MatchSize <= 6 then
    LevelVariatonTag = "Moon.LevelVariation.Small"
    BlueFlagSpawnTag = "RedBase.InteriorFront"
    RedFlagSpawnTag = "RedBase.InteriorRear"
elseif MatchSize <= 12 then
    LevelVariatonTag = "Moon.LevelVariation.Medium"
    BlueFlagSpawnTag = "RedBase.Front"
    RedFlagSpawnTag = "RedBase.Rear"
else
    LevelVariatonTag = nil
    BlueFlagSpawnTag = "Top.SideB"
    RedFlagSpawnTag = "Top.SideA"
end

if LevelVariatonTag ~= nil then
    Moon.LevelVariation.LoadLevelVariation(LevelVariatonTag)
end

local ScriptTuner = Moon.ScriptTuner.GetOrMake()

--Loot rules
local LootRules = Moon.MatchLootRules.Get()

LootRules.EnableLoot = ScriptTuner:GetBool("LootRules/Enabled", true)
LootRules.EnableDeathbags = ScriptTuner:GetBool("LootRules/Deathbags", true)
LootRules.DeathBagLifetime = 60
LootRules.RespawnLoot = ScriptTuner:GetBool("LootRules/Respawn", true)
LootRules.ContainerRespawnTime = ScriptTuner:GetInt("LootRules/ContainerDelay", 3) * 60
LootRules.PickupRespawnTime = ScriptTuner:GetInt("LootRules/PickupDelay", 1) * 60
--End loot rules

--Lua Globals
local ScoreToWin = ScriptTuner:GetInt("GameRules/ScoreLimit", 3)

local TimeToResetFlagSeconds = ScriptTuner:GetInt("GameRules/FlagReset", 20)

local TeamBlueColor = {R=0,B=.1,G=0,A=.1}
local TeamRedColor = {R=0.1,B=0,G=0,A=.1}

local TeamBlueColorBright = {R=0,B=1,G=0,A=1}
local TeamRedColorBright = {R=255,B=0,G=0,A=1}

local RoundTime = ScriptTuner:GetInt("GameRules/TimeLimit", 15) * 60
--End Lua Globals


-- Team Settings
local TeamSettings = Moon.Teams.Settings()
TeamSettings.AutoCreateTeams = false
TeamSettings.UseSquadColors = false

TeamA = Moon.Teams.GetOrMakeTeam("Red", TeamRedColorBright)
TeamB = Moon.Teams.GetOrMakeTeam("Blue", TeamBlueColorBright)
local AddToTeamB = true
-- End Team Settings


--Begin flag logic
--FlagHolders
FlagAHolder = nil
FlagBHolder = nil

FlagADroppedTimerHandle = nil
FlagBDroppedTimerHandle = nil

FlagAHolderObjective = nil
FlagBHolderObjective = nil

local TeamACurrentScore = 0
local TeamBCurrentScore = 0

local CustomStatName = "Captures"

--Flags/Triggers
local TaggedLocs = Moon.TaggedLocation.All()
local SideATop = Tagging.FilterByTag(TaggedLocs, RedFlagSpawnTag)[1]
local SideBTop = Tagging.FilterByTag(TaggedLocs, BlueFlagSpawnTag)[1]

local TriggerScale = {X=8, Y=8, Z=8}
local TriggerRotation = {Yaw=60, Pitch=0, Roll=0}
local TriggerA = Moon.Trigger.SpawnTrigger(SideATop:GetLocation(), TriggerScale, TriggerRotation)
TriggerA:SetColor(TeamRedColor)

local TriggerB = Moon.Trigger.SpawnTrigger(SideBTop:GetLocation(), TriggerScale, TriggerRotation)
TriggerB:SetColor(TeamBlueColor)

local FlagA = Moon.Interactable.SpawnInteractable("Interactable.Flag", SideATop:GetLocation())
FlagA:SetColor(TeamRedColor)
FlagA:AddBlockingInteractTag("Interaction.Block.A")

local FlagB = Moon.Interactable.SpawnInteractable("Interactable.Flag", SideBTop:GetLocation())
FlagB:SetColor(TeamBlueColor)
FlagB:AddBlockingInteractTag("Interaction.Block.B")

function AssignWinners(Team)		
    Audio.PlayGlobalSound({Sound=Audio.Sound.LargeEnderOne})

    GameMode:EndMatch(Team:GetTeamMembers())
    Moon.HudController.Get():AddWidget("MatchStats")
end

GameMode:SetMatchClock(RoundTime)
    MS.Utility.SetTimer(function ()
    if TeamACurrentScore > TeamBCurrentScore then
        AssignWinners(TeamA)
    elseif TeamBCurrentScore > TeamACurrentScore then
        AssignWinners(TeamB)
    else
        Audio.PlayGlobalSound({Sound=Audio.Sound.LargeEnderOne})
        GameMode:EndMatch({})
        Moon.HudController.Get():AddWidget("MatchStats")
    end
end, RoundTime)

function SetCallbacks(Flag, HomeTeam, OppositeTeam, FlagHolder, GoalTrigger, ResetLoc, Score, TimerHandle, ObjectiveHandle)	
    
    Flag.CanInteract:Connect(function (Player)
        return OppositeTeam:HasPlayer(Player)
    end)
    
    Flag.OnGrabbed:Connect(function (Player)
        local LocalObjective = Moon.ObjectiveSettings.Get(Player)
        ObjectiveHandle = LocalObjective:AddObjective({TargetLocation=GoalTrigger:GetLocation(), IndicatorType="Indicator.Objective.Flag"})

        FlagHolder = Player

        local HomeTeamMembers = HomeTeam:GetTeamMembers()
        for i = 1, #HomeTeamMembers do
            Audio.PlaySoundForPlayers({Sound=Audio.Sound.Alarm, Location=HomeTeamMembers[i]:GetLocation(), VolumeMultiplier=0.2, PitchMultiplier=4}, HomeTeam:GetTeamMembers())
        end

        local OppositeTeamMembers = OppositeTeam:GetTeamMembers()
        for i = 1, #OppositeTeamMembers do
            Audio.PlaySoundForPlayers({Sound=Audio.Sound.ActivateA, Location=OppositeTeamMembers[i]:GetLocation(), VolumeMultiplier=0.4}, OppositeTeam:GetTeamMembers())
        end

        if TimerHandle ~= nil then
            MS.Utility.ClearTimer(TimerHandle)
        end
        
        TimerHandle = nil

        Player:AddTag("Interaction.Block.Zipline")
        Player:AddTag("Interaction.Block.Car")
    end)
    
    Flag.OnDropped:Connect(function (Player)
        FlagHolder = nil

        local LocalObjective = Moon.ObjectiveSettings.Get(Player)
        LocalObjective:RemoveObjective(ObjectiveHandle)

        TimerHandle = MS.Utility.SetTimer(function ()
            Flag:SetInteractableLocation(ResetLoc)
        end, TimeToResetFlagSeconds)

        Player:RemoveTag("Interaction.Block.Zipline")
        Player:RemoveTag("Interaction.Block.Car")
    end)
    
    GoalTrigger.OnPlayerOverlapBegin:Connect(function (Actor)
        if FlagHolder ~= nil and Actor:GetName() == FlagHolder:GetName() then
            Moon.PlayerStats.AddCustomStatValue(FlagHolder, CustomStatName, 1)
            Flag:SetInteractableLocation(ResetLoc)
            
            Score = Score + 1
            if Score == ScoreToWin then
                AssignWinners(OppositeTeam)
            else
                Moon.AudioController.PlayGlobalSound({Sound=Audio.Sound.LargeObjectiveOne, VolumeMultiplier=0.6})
            end
        end
    end)
end

SetCallbacks(FlagA, TeamA, TeamB, FlagAHolder, TriggerB, SideATop:GetLocation(), TeamBCurrentScore, FlagADroppedTimerHandle, FlagAHolderObjective)
SetCallbacks(FlagB, TeamB, TeamA, FlagBHolder, TriggerA, SideBTop:GetLocation(), TeamACurrentScore, FlagBDroppedTimerHandle, FlagBHolderObjective)
--End flag logic


GameMode.RespawnDelay = ScriptTuner:GetInt("Spawn/RespawnDelay", 5)
GameMode.AutomaticRespawn = true
        
--Spawning
GameMode:AddPlayerStartFilter(function (Player, PlayerStarts)
    local OutPlayerStarts = {}
    local Tag = ""
    
    if TeamB:HasPlayer(Player) then
        Tag = "Spawn.SideB"
    else
        Tag = "Spawn.SideA"
    end
    
    for i = 1, #PlayerStarts do
        local MoonSpawn = Moon.PlayerStart.Cast(PlayerStarts[i])
        if MoonSpawn ~= nil then
            if MoonSpawn:HasTag(Tag) then
                table.insert(OutPlayerStarts, PlayerStarts[i])
            end
        end
    end
    
    if #OutPlayerStarts == 0 then
        MS.Utility.Log("Lua player filter found no valid player starts. Returning full array")
        return PlayerStarts
    else
        return OutPlayerStarts
    end
end)

--Weapons
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
    Player:GetBackpack():ClearInventory()
    Player:GetEquipment():ClearInventory()
    
    Player:GetEquipment():AddItem("SmallBackpack")
    Inventory.GrantStack(Player:GetBackpack(), "PistolAmmo")

    Player:SetInfiniteAmmo(false)

    Inventory.GrantWeapon(Player, Knife, true, false)
    Inventory.GrantWeapon(Player, SemiPistol, true, true)
end

GameMode.OnLogin:Connect(function (Player)
    if AddToTeamB == true then
        TeamB:AddPlayer(Player)
        Player:AddTag("Interaction.Block.B")
        AddToTeamB = false
    else
        TeamA:AddPlayer(Player)
        Player:AddTag("Interaction.Block.A")
        AddToTeamB = true
    end

    Effects.AddHealthRegen(Player)
end)

GameMode.OnRespawn:Connect(function(Player)
    InitPlayer(Player)
end)

GameMode.ShouldRespawn:Connect(function (Player)
    return true
end)

GameMode.GetPawnClass:Connect(function(Player)
    return "Default"
end)
--End configure Game Mode


--Stats
local HudController = Moon.HudController.Get()
HudController:AddWidget("ScoreBug")
HudController:AddWidget("TeamIndicators")
HudController:AddWidget("ObjectiveIndicators")

local GlobalObjectives = Moon.ObjectiveSettings.Get()
GlobalObjectives:AddObjective({TargetActor=FlagA, IndicatorType="Indicator.Objective.Flag", IndicatorColor=TeamRedColorBright, IndicatorOffset={X=0,Y=0,Z=250}})
GlobalObjectives:AddObjective({TargetActor=FlagB, IndicatorType="Indicator.Objective.Flag", IndicatorColor=TeamBlueColorBright, IndicatorOffset={X=0,Y=0,Z=250}})

local ScoreUISettings = Moon.ScoreUISettings.Get()
ScoreUISettings.StatName = CustomStatName
ScoreUISettings.MatchDescription = "3 captures to win"
ScoreUISettings.MatchName = "Capture The Flag" 
ScoreUISettings.WinLimit = ScoreToWin
ScoreUISettings.DisplayPlayerName = false
ScoreUISettings.ShowTeamName = true
ScoreUISettings.ShowPlace = false
ScoreUISettings.IsTeamMatch = true
ScoreUISettings.ShowClock = true

local Columns = ScoreUISettings.MatchStatColumns
table.insert(Columns, 1, CustomStatName)
ScoreUISettings.MatchStatColumns = Columns
--end stats

