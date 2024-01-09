MidnightUtility = require("MidnightUtility")

local Module = {}

local globalprint = print
print = function (...)
	globalprint("TeamCreationModule: ", ...)
end

Module.GroupByMatchmakingTeam = true
Module.DynamicTeaming = false
Module.AutoCreateTeams = false
Module.TeamSizes = 0

--Minimum supported team sizes if dynamic teaming (for now)
local MinimumSupportedTeamSizes = 3
--How many more players can this team have?
local TeamRemainingCapacity =  MidnightUtility.MidnightTable.New()

--How many more bots can this team have?
local TeamRemainingBotCapacity =  MidnightUtility.MidnightTable.New()

--How many players are on each team?
local CurrentTeamSizes = MidnightUtility.MidnightTable.New()

--How many bots are on each team?
local CurrentTeamSizesBot = MidnightUtility.MidnightTable.New()

--Is there already a team for this player?
local TeamLookup = {}

--Work around for now since we can't store actual objects as keys
local TeamMapping = MidnightUtility.MidnightTable.New()

--Have we detected something that indicates we are not hooked into matchmaking?
local ValidBackend = true

local OnPlayerAddedToTeam = nil

function Module.SetOnPlayerAddedToTeam(PlayerAddToTeamFunc)
	OnPlayerAddedToTeam = PlayerAddToTeamFunc
end

function InitNewTeam(Name, Color)
	local NewTeam = nil

	if Color ~= nil then
		NewTeam = Moon.Teams.GetOrMakeTeam(Name, Color)
	else
		NewTeam = Moon.Teams.GetOrMakeTeam(Name)
	end

	CurrentTeamSizes[NewTeam] = 0
	CurrentTeamSizesBot[NewTeam] = 0
	TeamMapping[NewTeam] = NewTeam
	TeamRemainingCapacity[NewTeam] = Module.TeamSizes
	TeamRemainingBotCapacity[NewTeam] = Module.TeamSizes

	print("Created new team: " .. NewTeam:GetName() .. " With remaining capacity: " .. tostring(Module.TeamSizes))

	return NewTeam
end

function Module.AddTeam(TeamName, TeamColor)
	return InitNewTeam(TeamName, TeamColor)
end

local PlayerBotManager = Moon.PlayerBotManager.Get()

function AddPlayerToTeam(Player, Team, MatchmakingTeamId, MatchmakingTeamSize)
	local IsPlayerABot = PlayerBotManager:IsPlayerABot(Player)

	if IsPlayerABot then
		print("Add bot to " .. Team:GetName())
	else
		print("Add player to " .. Team:GetName())
	end

	if  IsPlayerABot == false then
		CurrentTeamSizes[Team] = CurrentTeamSizes[Team] + MatchmakingTeamSize
		TeamRemainingCapacity[Team] = TeamRemainingCapacity[Team] - MatchmakingTeamSize

		print("Remaing player capacity for " .. Team:GetName() .. " is " .. tostring(TeamRemainingCapacity[Team]))

		local Members = Team:GetTeamMembers()
		for i = 1, #Members do
			if PlayerBotManager:IsPlayerABot(Members[i]) then
				print("Removed bot from " .. Team:GetName())
				Team:RemovePlayer(Members[i])
				PlayerBotManager:RemovePlayerBot(Members[i])
				break
			end
		end
	else
		TeamRemainingBotCapacity[Team] = TeamRemainingBotCapacity[Team] - 1
		CurrentTeamSizesBot[Team] = CurrentTeamSizesBot[Team] + 1
	end

	Team:AddPlayer(Player)

	if OnPlayerAddedToTeam ~= nil then
		OnPlayerAddedToTeam(Player, Team)
	end
	
	if ValidBackend then
		TeamLookup[MatchmakingTeamId] = Team
	end
end

local GameMode = Moon.GameMode.First()
local NextTeamId = 1
function DynamicAdd(Player, MatchmakingTeamId, MatchmakingTeamSize)
	local TeamToAddTo = nil

	local RemainingCapicityTable = nil

	if PlayerBotManager:IsPlayerABot(Player) then
		RemainingCapicityTable = TeamRemainingBotCapacity
	else
		RemainingCapicityTable = TeamRemainingCapacity
	end

	--Check if there is a team to accomdate this party
	for k,v in pairs(RemainingCapicityTable) do
		if v >= MatchmakingTeamSize and k ~= nil then
			TeamToAddTo = TeamMapping[k]
			break
		end
	end

	if TeamToAddTo == nil then
		TeamToAddTo = InitNewTeam("Team " .. tostring(NextTeamId), nil)
		NextTeamId = NextTeamId + 1
	end

	AddPlayerToTeam(Player, TeamToAddTo, MatchmakingTeamId, MatchmakingTeamSize)
end

function SetTeamAdd(Player, MatchmakingTeamId, MatchmakingTeamSize)	
	local TeamToAddTo = nil
	local LowestCurrentSize = 9999

	local CurrentTeamSizesTable = nil

	if PlayerBotManager:IsPlayerABot(Player) then
		CurrentTeamSizesTable = CurrentTeamSizesBot
	else
		CurrentTeamSizesTable = CurrentTeamSizes
	end

	--Check if there is a team to accomdate this party
	for k,v in pairs(CurrentTeamSizesTable) do
		if v < LowestCurrentSize and k ~= nil then
			LowestCurrentSize = v
			TeamToAddTo = TeamMapping[k]
		end
	end

	AddPlayerToTeam(Player, TeamToAddTo, MatchmakingTeamId, MatchmakingTeamSize)
end

--Call this before adding bots or players
function Module.Initialize(TuningTable)
	Module.GroupByMatchmakingTeam = TuningTable.GroupByMatchmakingTeam or Module.GroupByMatchmakingTeam
	Module.DynamicTeaming = TuningTable.DynamicTeaming or Module.DynamicTeaming
	Module.AutoCreateTeams = TuningTable.AutoCreateTeams or Module.AutoCreateTeams
	Module.TeamSizes = TuningTable.TeamSizes or Module.TeamSizes

	if Module.DynamicTeaming and Module.TeamSizes < MinimumSupportedTeamSizes then
		Module.TeamSizes = MinimumSupportedTeamSizes
	end
	
	if Module.AutoCreateTeams == false then		
		-- Team Settings
		local TeamSettings = Moon.Teams.Settings()
		TeamSettings.AutoCreateTeams = Module.AutoCreateTeams

		GameMode.OnLogin:Connect(function (Player)
			local MatchmakingTeamId = Player:GetMatchmakingTeamId()		
			local MatchmakingTeamSize = GameMode:MatchmakingTeamSize(MatchmakingTeamId)

			local IsPlayerBot = PlayerBotManager:IsPlayerABot(Player)

			if MatchmakingTeamSize == 0 and IsPlayerBot == false then --this means we aren't hooked into matchmaking
				MatchmakingTeamSize = 1
				print("Detected no backend")
				ValidBackend = false
			end

			if Module.GroupByMatchmakingTeam and TeamLookup[MatchmakingTeamId] ~= nil and IsPlayerBot == false then
				--If we get into here the team has already accounted for having this player

				local AddTeam = TeamLookup[MatchmakingTeamId]

				if AddTeam ~= nil then
					AddTeam:AddPlayer(Player)
					local Members = AddTeam:GetTeamMembers()
					for i = 1, #Members do
						if PlayerBotManager:IsPlayerABot(Members[i]) then
							print("Removed bot from " .. AddTeam:GetName())
							AddTeam:RemovePlayer(Members[i])
							PlayerBotManager:RemovePlayerBot(Members[i])
							break
						end
					end
				end
				return
			end
		
			if Module.GroupByMatchmakingTeam == false or IsPlayerBot then
				MatchmakingTeamSize = 1
			end

			if Module.DynamicTeaming then
				DynamicAdd(Player, MatchmakingTeamId, MatchmakingTeamSize)
			else
				SetTeamAdd(Player, MatchmakingTeamId, MatchmakingTeamSize)
			end
		end)
	end

end

print("Loading")
-- ModuleScripts must return exactly one value
return Module