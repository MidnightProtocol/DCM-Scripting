local Inventory = require("Modules/Inventory")
local SpawnFilters = require("Modules/SpawnFilters")
local Tagging = require("Modules/Tagging")
local Audio = require("Modules/Audio")
local Effects = require("Modules/Effects")
local MidnightUtility = require("Modules/MidnightUtility")
local TeamCreation = require("Modules/TeamCreation")

--Configure Game Mode
local GameMode = Moon.GameMode.First()

local MatchSize = GameMode:MatchSize()

LevelVariatonTag = nil
TeamBFlagSpawnTags = {}
TeamAFlagSpawnTags = {}
NeutralSpawnTags = {}

local ScriptTuner = Moon.ScriptTuner.GetOrMake()
local EnableNeutralFlag = ScriptTuner:GetBool("GameRules/EnableNeutralFlag", true)
local EnableRandomFlagSpawns = ScriptTuner:GetBool("GameRules/EnableRandomFlagSpawns", true)
local NeutralFlagPoints = ScriptTuner:GetInt("GameRules/NeutralFlagPoints", 5)

local NeutralFlagSpawnTime = math.random(9, 13) * 60

if MatchSize <= 6 then
    LevelVariatonTag = "Moon.LevelVariation.Small"

    if EnableRandomFlagSpawns then
        TeamBFlagSpawnTags = {"RedBase.InteriorFront", "RedBase.InteriorFrontLeft", "RedBase.InteriorFrontRight"}
        TeamAFlagSpawnTags = {"RedBase.InteriorBackLeft", "RedBase.InteriorBackRight", "RedBase.InteriorRear"}
        NeutralSpawnTags = {"Top.SideA", "RedBase.PeakRight", "RedBase.PeakLeft"}
    else
        TeamBFlagSpawnTags = {"RedBase.InteriorFront"}
        TeamAFlagSpawnTags = {"RedBase.InteriorRear"}
        NeutralSpawnTags = {"Top.SideA"}
    end

    NeutralFlagSpawnTime = math.random(4, 6) * 60
elseif MatchSize <= 18 then
    LevelVariatonTag = "Moon.LevelVariation.Medium"

    if EnableRandomFlagSpawns then
        TeamBFlagSpawnTags = {"RedBase.InteriorFront", "RedBase.InteriorFrontLeft", "RedBase.InteriorFrontRight", "RedBase.Front", "RedBase.FrontLeft", "RedBase.FrontRight"}
        TeamAFlagSpawnTags = {"RedBase.InteriorBackLeft", "RedBase.InteriorBackRight", "RedBase.InteriorRear", "RedBase.BackLeft", "RedBase.BackRight", "RedBase.Rear"}
        NeutralSpawnTags = {"RedBase.Right", "RedBase.Left", "Top.SideA", "RedBase.PeakRight", "RedBase.PeakLeft"}
    else
        TeamBFlagSpawnTags = {"RedBase.Front"}
        TeamAFlagSpawnTags = {"RedBase.Rear"}
        NeutralSpawnTags = {"Top.SideA"}
    end

    NeutralFlagSpawnTime = math.random(5, 9) * 60
else
    LevelVariatonTag = nil

    if EnableRandomFlagSpawns then
        TeamBFlagSpawnTags = {"BlueBase.Left", "BlueBase.LeftPeak", "BlueBase.RightPeak", "BlueBase.Right", "Top.SideB"}
        TeamAFlagSpawnTags = {"RedBase.Left", "RedBase.PeakLeft", "RedBase.PeakRight", "RedBase.Right", "Top.SideA"}
        NeutralSpawnTags = {"Neutral.High", "Neutral.Left", "Neutral.Low", "Neutral.Right"}
    else
        TeamBFlagSpawnTags = {"Top.SideB"}
        TeamAFlagSpawnTags = {"Top.SideA"}
        NeutralSpawnTags = {"Neutral.High"}
    end
end

if LevelVariatonTag ~= nil then
    Moon.LevelVariation.LoadLevelVariation(LevelVariatonTag)
end

--Loot rules
local LootRules = Moon.MatchLootRules.Get()
LootRules.EnableLoot = ScriptTuner:GetBool("Loot/Enabled", true)
LootRules.EnableDeathbags = ScriptTuner:GetBool("Loot/Deathbags", true)
LootRules.DeathBagLifetime = ScriptTuner:GetInt("Loot/DeathbagLifetimes", 60)
LootRules.RespawnLoot = ScriptTuner:GetBool("Loot/Respawn", true)
LootRules.ContainerRespawnTime = ScriptTuner:GetInt("Loot/ContainerDelay", 3) * 60
LootRules.PickupRespawnTime = ScriptTuner:GetInt("Loot/PickupDelay", 1) * 60
--End loot rules

--Lua Globals
local ScoreToWin = ScriptTuner:GetInt("GameRules/ScoreLimit", 5)

local TimeToResetFlagSeconds = ScriptTuner:GetInt("GameRules/FlagReset", 20)

local TeamBlueColor = {R=0.009721, G=0.351532, B=0.846873, A=0.1}
local TeamRedColor = {R=0.846873, G=0.009721, B=0.048172, A=0.1}

local TeamBlueColorBright = {R=0.009721, G=0.351532, B=0.846873, A=1.0}
local TeamRedColorBright = {R=0.846873, G=0.009721, B=0.048172, A=1}

local RoundTime = ScriptTuner:GetInt("GameRules/TimeLimit", 20) * 60

--End Lua Globals

-- Team Settings
local TeamSettings = Moon.Teams.Settings()
TeamSettings.AutoCreateTeams = false
TeamSettings.UseSquadColors = false

TeamA = TeamCreation.AddTeam("Red", TeamRedColorBright)
TeamB = TeamCreation.AddTeam("Blue", TeamBlueColorBright)

function OnPlayerAddedToTeam(Player, Team)
    if Team:GetName() == TeamB:GetName() then
        Player:AddTag("Interaction.Block.B")
    else
        Player:AddTag("Interaction.Block.A")
    end
end

TeamCreation.SetOnPlayerAddedToTeam(OnPlayerAddedToTeam)
TeamCreation.Initialize(TeamCreation)
-- End Team Settings

--Begin flag logic
--FlagHolders
FlagAHolder = nil
FlagBHolder = nil

FlagADroppedTimerHandle = nil
FlagBDroppedTimerHandle = nil

FlagAHolderObjective = nil
FlagBHolderObjective = nil

Scores = MidnightUtility.MidnightTable.New()
Scores[TeamA] = 0
Scores[TeamB] = 0

local CustomStatName = "Captures"

local TaggedLocs = Moon.TaggedLocation.All()

function GetRandomLoc(PossibleTags)
    local ShuffedTags = MidnightUtility.Shuffle(PossibleTags)

    for i = 1, #ShuffedTags do
        local NewLocs = Tagging.FilterByTag(TaggedLocs, ShuffedTags[1])

        if #NewLocs > 0 then
            return NewLocs[1]:GetLocation()
        end
    end

    return {X=0,Y=0,Z=0}
end

local TriggerScale = {X=8, Y=8, Z=8}
local TriggerRotation = {Yaw=60, Pitch=0, Roll=0}

local TeamALoc = GetRandomLoc(TeamAFlagSpawnTags)
local TriggerA = Moon.Trigger.SpawnTrigger(TeamALoc, TriggerScale, TriggerRotation)
TriggerA:SetColor(TeamRedColor)
local FlagA = Moon.Interactable.SpawnInteractable("Interactable.Flag", TeamALoc)
local FlagAResetLoc = TeamALoc
FlagA:SetColor(TeamRedColor)
FlagA:AddBlockingInteractTag("Interaction.Block.A")

local TeamBLoc = GetRandomLoc(TeamBFlagSpawnTags)
local TriggerB = Moon.Trigger.SpawnTrigger(TeamBLoc, TriggerScale, TriggerRotation)
TriggerB:SetColor({R=0.0, G=0.0, B=0.6, A=0.1})
local FlagB = Moon.Interactable.SpawnInteractable("Interactable.Flag", TeamBLoc)
FlagB:SetColor(TeamBlueColor)
FlagB:AddBlockingInteractTag("Interaction.Block.B")
local FlagBResetLoc = TeamBLoc


local GlobalObjectives = Moon.ObjectiveSettings.Get()

FlagAObjective = GlobalObjectives:AddObjective({TargetActor=FlagA, IndicatorType="Indicator.Objective.Flag", IndicatorColor=TeamRedColorBright, IndicatorOffset={X=0,Y=0,Z=250}})
FlagBObjective = GlobalObjectives:AddObjective({TargetActor=FlagB, IndicatorType="Indicator.Objective.Flag", IndicatorColor=TeamBlueColorBright, IndicatorOffset={X=0,Y=0,Z=250}})

local ScoreUISettings = Moon.ScoreUISettings.Get()

function AssignWinners(Team)		
    Audio.PlayGlobalSound({Sound=Audio.Sound.LargeEnderOne, VolumeMultiplier=0.6})
    ScoreUISettings:SetMatchDescription(Team:GetDisplayName() .. " Team Wins")
    GameMode:EndMatch(Team:GetTeamMembers())
    Moon.HudController.Get():AddWidget("MatchStats")
end

GameMode:SetMatchClock(RoundTime)
MS.Utility.SetTimer(function ()
    if Scores[TeamA] > Scores[TeamB] then
        AssignWinners(TeamA)
    elseif Scores[TeamB] > Scores[TeamA] then
        AssignWinners(TeamB)
    else
        Audio.PlayGlobalSound({Sound=Audio.Sound.LargeEnderOne, VolumeMultiplier=0.6})
        GameMode:EndMatch({})
        Moon.HudController.Get():AddWidget("MatchStats")
    end
end, RoundTime)

NeutralObjectiveHandle = nil
NeutralFlagHolder = nil

local TeamAFlagObjHandles = MidnightUtility.MidnightTable.New()
local TeamBFlagObjHandles = MidnightUtility.MidnightTable.New()

function AddFlagObjectiveForPlayers(Players, Flag, Color, ObjHandles)
    for i = 1, #Players do 
        local LocalObjective = Moon.ObjectiveSettings.Get(Players[i])
        ObjHandles[Players[i]] = nil
        ObjHandles[Players[i]] = {PlayerObj = Players[i], ObjHandle = LocalObjective:AddObjective({TargetActor=Flag, IndicatorType="Indicator.Objective.Flag", IndicatorColor=Color, IndicatorOffset={X=0,Y=0,Z=250}})}
    end
end

function RemoveFlagObjectiveForPlayers(ObjHandles)
    if ObjHandles ~= nil then
        for key, value in pairs(ObjHandles) do 
            if value.PlayerObj ~= nil then
                local LocalObjective = Moon.ObjectiveSettings.Get(value.PlayerObj)
                if LocalObjective ~= nil then
                    LocalObjective:RemoveObjective(value.ObjHandle)
                end
            end
        end
    end
    ObjHandles = nil
end

function SetCallbacks(Flag, HomeTeam, OppositeTeam, FlagHolder, GoalTrigger, ResetLoc, TimerHandle, ObjectiveHandle, HomeTrigger, FlagSpawnLocs, FlagObjective, TeamObjColor, AwayTeamObjHandle, HomeTeamObjHandles)	
    Flag.CanInteract:Connect(function (Player)
        return OppositeTeam:HasPlayer(Player)
    end)
    
    Flag.OnGrabbed:Connect(function (Player)
        local LocalObjective = Moon.ObjectiveSettings.Get(Player)
        ObjectiveHandle = LocalObjective:AddObjective({TargetLocation=GoalTrigger:GetLocation(), IndicatorType="Indicator.Objective.Flag"})

        FlagHolder = Player

        Tagging.AddTag(Player, "HoldingFlag")

        local HomeTeamMembers = HomeTeam:GetTeamMembers()
        Audio.PlaySoundForPlayers({Sound=Audio.Sound.Alarm, VolumeMultiplier=0.2, PitchMultiplier=4}, HomeTeam:GetTeamMembers())

        local OppositeTeamMembers = OppositeTeam:GetTeamMembers()
        Audio.PlaySoundForPlayers({Sound=Audio.Sound.ActivateA, VolumeMultiplier=0.4}, OppositeTeam:GetTeamMembers())

        if TimerHandle ~= nil then
            MS.Utility.ClearTimer(TimerHandle)
        end
        
        TimerHandle = nil

        if FlagObjective ~= nil then
            GlobalObjectives:RemoveObjective(FlagObjective)
            FlagObjective = nil
        end

        AddFlagObjectiveForPlayers(OppositeTeam:GetTeamMembers(), Flag, TeamObjColor, AwayTeamObjHandle)

        Player:AddTag("Interaction.Block.Zipline")
        Player:AddTag("Interaction.Block.Car")
    end)
    
    Flag.OnDropped:Connect(function (Player)
        
        print("lua on dropped")

        Tagging.RemoveTag(Player, "HoldingFlag")

        FlagHolder = nil
        local LocalObjective = Moon.ObjectiveSettings.Get(Player)
        LocalObjective:RemoveObjective(ObjectiveHandle)

        TimerHandle = MS.Utility.SetTimer(function ()
            Flag:SetInteractableLocation(ResetLoc)
        end, TimeToResetFlagSeconds)

        RemoveFlagObjectiveForPlayers(AwayTeamObjHandle)
        RemoveFlagObjectiveForPlayers(HomeTeamObjHandles)

        if FlagObjective == nil then
            FlagObjective = GlobalObjectives:AddObjective({TargetActor=Flag, IndicatorType="Indicator.Objective.Flag", IndicatorColor=TeamObjColor, IndicatorOffset={X=0,Y=0,Z=250}})
        end

        Player:RemoveTag("Interaction.Block.Zipline")
        Player:RemoveTag("Interaction.Block.Car")
    end)
    
    GoalTrigger.OnPlayerOverlapBegin:Connect(function (Actor)
        if FlagHolder ~= nil and Actor:GetName() == FlagHolder:GetName() then
            Moon.PlayerStats.AddCustomStatValue(FlagHolder, CustomStatName, 1)
            Moon.TelemetryEvents.SendPlayerTelemtryEvent(FlagHolder, '{"mcmEventType":"FlagScore", "flagScorePoints":1}')
            FlagHolder = nil

            print("Lua flag holder cleared ")
        
            local NewLoc = GetRandomLoc(FlagSpawnLocs)
            Flag:SetInteractableLocation(NewLoc)
            HomeTrigger:SetLocation(NewLoc)

            Scores[OppositeTeam] = Scores[OppositeTeam] + 1
            ResetLoc = NewLoc
            
            RemoveFlagObjectiveForPlayers(TeamObjHandle)
            RemoveFlagObjectiveForPlayers(HomeTeamObjHandles)

            if FlagObjective == nil then
                FlagObjective = GlobalObjectives:AddObjective({TargetActor=Flag, IndicatorType="Indicator.Objective.Flag", IndicatorColor=TeamObjColor, IndicatorOffset={X=0,Y=0,Z=250}})
            end

            if NeutralFlagHolder ~= nil and HomeTeam:HasPlayer(NeutralFlagHolder) then
                local LocalObjective = Moon.ObjectiveSettings.Get(NeutralFlagHolder)
                LocalObjective:RemoveObjective(NeutralObjectiveHandle)
                NeutralObjectiveHandle = LocalObjective:AddObjective({TargetLocation=NewLoc, IndicatorType="Indicator.Objective.Flag"})
            end

            if Scores[OppositeTeam] >= ScoreToWin then
                AssignWinners(OppositeTeam)
            else
                Moon.AudioController.PlayGlobalSound({Sound=Audio.Sound.LargeObjectiveOne, VolumeMultiplier=0.6})
            end
        end
    end)

    GameMode.OnLogout:Connect(function (Player)
        if FlagHolder ~= nil and Player:GetName() == FlagHolder:GetName() then
            Flag:SetInteractableLocation(ResetLoc)
            Tagging.RemoveTag(Player, "HoldingFlag")

            FlagHolder = nil
            local LocalObjective = Moon.ObjectiveSettings.Get(Player)
            LocalObjective:RemoveObjective(ObjectiveHandle)
    
            TimerHandle = MS.Utility.SetTimer(function ()
                Flag:SetInteractableLocation(ResetLoc)
            end, TimeToResetFlagSeconds)
    
            RemoveFlagObjectiveForPlayers(AwayTeamObjHandle)
            RemoveFlagObjectiveForPlayers(HomeTeamObjHandles)
    
            if FlagObjective == nil then
                FlagObjective = GlobalObjectives:AddObjective({TargetActor=Flag, IndicatorType="Indicator.Objective.Flag", IndicatorColor=TeamObjColor, IndicatorOffset={X=0,Y=0,Z=250}})
            end
    
            Player:RemoveTag("Interaction.Block.Zipline")
            Player:RemoveTag("Interaction.Block.Car")
        end
    end)
end

SetCallbacks(FlagA, TeamA, TeamB, FlagAHolder, TriggerB, FlagAResetLoc, FlagADroppedTimerHandle, FlagAHolderObjective, TriggerA, TeamAFlagSpawnTags, FlagAObjective, TeamRedColorBright, TeamBFlagObjHandles, TeamAFlagObjHandles)
SetCallbacks(FlagB, TeamB, TeamA, FlagBHolder, TriggerA, FlagBResetLoc, FlagBDroppedTimerHandle, FlagBHolderObjective, TriggerB, TeamBFlagSpawnTags, FlagBObjective, TeamBlueColorBright, TeamAFlagObjHandles, TeamBFlagObjHandles)


local MessageController = Moon.MessageController.Get()

function SpawnNeutral()
    MessageController:SendMessageToAll("Neutral Flag Has Spawned", 10)
    Moon.AudioController.PlayGlobalSound({Sound=Audio.Sound.TechStingerOne, VolumeMultiplier=0.3, PitchMultiplier=0.8})
    local NeutralSpawn = GetRandomLoc(NeutralSpawnTags)
    local NeutralFlag = Moon.Interactable.SpawnInteractable("Interactable.Flag", NeutralSpawn)
    FlagB:SetColor({R=0,B=0,G=0,A=1})

    GlobalObjectives:AddObjective({TargetActor=NeutralFlag, IndicatorType="Indicator.Objective.Flag", IndicatorColor={R=1,B=1,G=1,A=1}, IndicatorOffset={X=0,Y=0,Z=250}})

    NeutralFlag.OnGrabbed:Connect(function (Player)
        local LocalObjective = Moon.ObjectiveSettings.Get(Player)

        local GoalLoc = nil
        
        if TeamA:HasPlayer(Player) then
            GoalLoc = TriggerA:GetLocation()
        else
            GoalLoc = TriggerB:GetLocation()
        end

        NeutralObjectiveHandle = LocalObjective:AddObjective({TargetLocation=GoalLoc, IndicatorType="Indicator.Objective.Flag"})

        NeutralFlagHolder = Player

        local HomeTeamMembers = {}
        local OppositeTeamMembers = {}
        
        if TeamB:HasPlayer(Player) then
            HomeTeamMembers = TeamB:GetTeamMembers()
            OppositeTeamMembers = TeamA:GetTeamMembers()
        else
            HomeTeamMembers = TeamA:GetTeamMembers()
            OppositeTeamMembers = TeamB:GetTeamMembers()
        end

        for i = 1, #OppositeTeamMembers do
            Audio.PlaySoundForPlayer({Sound=Audio.Sound.Alarm, Location=OppositeTeamMembers[i]:GetLocation(), VolumeMultiplier=0.2, PitchMultiplier=4}, OppositeTeamMembers[i])
        end

        for i = 1, #HomeTeamMembers do
            Audio.PlaySoundForPlayer({Sound=Audio.Sound.ActivateA, Location=HomeTeamMembers[i]:GetLocation(), VolumeMultiplier=0.4}, HomeTeamMembers[i])
        end
    end)

    NeutralFlag.OnDropped:Connect(function (Player)
        local LocalObjective = Moon.ObjectiveSettings.Get(Player)
        LocalObjective:RemoveObjective(NeutralObjectiveHandle)
        NeutralObjectiveHandle = nil
        NeutralFlagHolder = nil
    end)

    TriggerA.OnPlayerOverlapBegin:Connect(function (Actor)
        local AsPlayer = Moon.Player.Cast(Actor)

        if NeutralFlagHolder ~= nil and AsPlayer ~= nil then
            if NeutralFlagHolder:GetName() == AsPlayer:GetName() and TeamA:HasPlayer(AsPlayer) then

                Moon.PlayerStats.AddCustomStatValue(NeutralFlagHolder, CustomStatName, 2)
                Moon.TelemetryEvents.SendPlayerTelemtryEvent(NeutralFlagHolder, '{"mcmEventType":"FlagScore", "flagScorePoints":1}')

                local LocalObjective = Moon.ObjectiveSettings.Get(AsPlayer)
                LocalObjective:RemoveObjective(NeutralObjectiveHandle)
                NeutralObjectiveHandle = nil
                NeutralFlagHolder = nil

                NeutralFlag.OnDropped:Clear()
                NeutralFlag.OnGrabbed:Clear()

                NeutralFlag:Destroy()

                Scores[TeamA] = Scores[TeamA] + 2
                if Scores[TeamA] >= ScoreToWin then
                    AssignWinners(TeamA)
                else
                    Moon.AudioController.PlayGlobalSound({Sound=Audio.Sound.LargeObjectiveOne, VolumeMultiplier=0.6})
                end
            end
        end
    end)

    TriggerB.OnPlayerOverlapBegin:Connect(function (Actor)
        local AsPlayer = Moon.Player.Cast(Actor)

        if NeutralFlagHolder ~= nil and AsPlayer ~= nil then
            if NeutralFlagHolder:GetName() == AsPlayer:GetName() and TeamB:HasPlayer(AsPlayer) then

                Moon.PlayerStats.AddCustomStatValue(NeutralFlagHolder, CustomStatName, 2)
                Moon.TelemetryEvents.SendPlayerTelemtryEvent(NeutralFlagHolder, '{"FlagScorePoints":2}')

                local LocalObjective = Moon.ObjectiveSettings.Get(AsPlayer)
                LocalObjective:RemoveObjective(NeutralObjectiveHandle)
                NeutralObjectiveHandle = nil
                NeutralFlagHolder = nil
         
                NeutralFlag.OnDropped:Clear()
                NeutralFlag.OnGrabbed:Clear()

                NeutralFlag:Destroy()

                Scores[TeamB] = Scores[TeamB] + 2
                if Scores[TeamB] >= ScoreToWin then
                    AssignWinners(TeamB)
                else
                    Moon.AudioController.PlayGlobalSound({Sound=Audio.Sound.LargeObjectiveOne, VolumeMultiplier=0.6})
                end
            end
        end
    end)

    GameMode.OnLogout:Connect(function (Player)
        if NeutralFlagHolder ~= nil and Player:GetName() == NeutralFlagHolder:GetName() then
            NeutralFlag:SetInteractableLocation(NeutralSpawn)
            local LocalObjective = Moon.ObjectiveSettings.Get(Player)
            LocalObjective:RemoveObjective(NeutralObjectiveHandle)
            NeutralObjectiveHandle = nil
            NeutralFlagHolder = nil
        end
    end)
end



if EnableNeutralFlag then
    MS.Utility.SetTimer(SpawnNeutral, NeutralFlagSpawnTime, false)
end
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
    Player:OnTagAdded("State.Sprinting", function()
        if Tagging.HasTag(Player, "HoldingFlag") then
            if TeamA:HasPlayer(Player) then
                AddFlagObjectiveForPlayers(TeamB:GetTeamMembers(), FlagB, TeamBlueColorBright, TeamBFlagObjHandles)
            else
                AddFlagObjectiveForPlayers(TeamA:GetTeamMembers(), FlagA, TeamRedColorBright, TeamAFlagObjHandles)
            end
        end
    end)

    Player:OnTagRemoved("State.Sprinting", function()
        if Tagging.HasTag(Player, "HoldingFlag") then
            if TeamA:HasPlayer(Player) then
                RemoveFlagObjectiveForPlayers(TeamBFlagObjHandles)
            else
                RemoveFlagObjectiveForPlayers(TeamAFlagObjHandles)
            end
        end
    end)

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

ScoreUISettings.StatName = CustomStatName
ScoreUISettings:SetMatchDescription("5 captures to win")
ScoreUISettings:SetMatchName("Capture The Flag") 
ScoreUISettings.WinLimit = ScoreToWin
ScoreUISettings.DisplayPlayerName = false
ScoreUISettings.ShowTeamName = true
ScoreUISettings.ShowPlace = false
ScoreUISettings.IsTeamMatch = true
ScoreUISettings.ShowClock = true

local Columns = ScoreUISettings:GetMatchStatColumns()
table.insert(Columns, 1, CustomStatName)
ScoreUISettings:SetMatchStatColumns(Columns)
--end stats

