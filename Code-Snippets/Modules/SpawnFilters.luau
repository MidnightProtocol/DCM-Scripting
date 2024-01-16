local Module = {}
local Math = require("Modules/Math")

MS.Utility.Log("Loading SpawnFilters.luau!")

Module.MinimumSpawnSqDistance = 5000 * 5000
Module.MaximumTeamSpawnSqDistance = 3000 * 3000

Module.MediumMaxDist = 30000 * 30000
Module.MediumMinDist = 10000 * 10000

local function FilterOnRejectCondition(Player, PlayerStarts, RejectConditionFunction)
	local OutPlayerStarts = {}
	local Players = Moon.Player.All()
	
	for i = 1, #PlayerStarts do
		local bShouldAddStart = true
		
		for j = 1, #Players do
			if RejectConditionFunction(Player, Players[j], PlayerStarts[i]) then
				bShouldAddStart = false
			end
		end
			
		if bShouldAddStart == true then
			table.insert(OutPlayerStarts, PlayerStarts[i])
		end
	end
	
	--If by crazy chance every point is filtered out
	if #OutPlayerStarts == 0 then
		MS.Utility.Log("Lua player filter found no valid player starts. Returning full array")
		return PlayerStarts
	else
		return OutPlayerStarts
	end
end

function Module.MinimumSpawnDistanceFilter(Player, PlayerStarts)
	return FilterOnRejectCondition(Player, PlayerStarts, function(SpawningPlayer, OtherPlayer, PlayerStart)
			local StartLoc = PlayerStart:GetLocation()

			local SpawnerTeam = Moon.Team.GetPlayersTeam(SpawningPlayer)
			local CheckAgainstTeam = Moon.Team.GetPlayersTeam(OtherPlayer)
			
			local ValidPawn = OtherPlayer:IsAlive()
			local DifferentPlayer = OtherPlayer:GetName() ~= SpawningPlayer:GetName()
			
			local DifferentTeam = SpawnerTeam ~= nil 
				and CheckAgainstTeam ~= nil 
				and SpawnerTeam:GetName() ~= CheckAgainstTeam:GetName()
			
			local NoTeam = SpawnerTeam == nil or CheckAgainstTeam == nil
	
			local TeamCondition = DifferentTeam or NoTeam
			
			if ValidPawn and DifferentPlayer and TeamCondition then
				local PlayerLoc = OtherPlayer:GetLocation()
				local SquareDistance = Math.SquaredDist3d(StartLoc, PlayerLoc)
				
				if SquareDistance < Module.MinimumSpawnSqDistance then
					return true
				end
			end
			
			return false
		end)
end

function Module.CloseToTeamFilter(Player, PlayerStarts)
	return FilterOnRejectCondition(Player, PlayerStarts, function(SpawningPlayer, OtherPlayer, PlayerStart)
			local StartLoc = PlayerStart:GetLocation()

			local SpawnerTeam = Moon.Team.GetPlayersTeam(SpawningPlayer)
			local CheckAgainstTeam = Moon.Team.GetPlayersTeam(OtherPlayer)
			
			local ValidPawn = OtherPlayer:IsAlive()
			local DifferentPlayer = OtherPlayer:GetName() ~= SpawningPlayer:GetName()
			local SameTeam = SpawnerTeam ~= nil 
				and CheckAgainstTeam ~= nil 
				and SpawnerTeam:GetName() == CheckAgainstTeam:GetName()
			
			if ValidPawn and DifferentPlayer and SameTeam then
				local PlayerLoc = OtherPlayer:GetLocation()
				local SquareDistance = Math.SquaredDist3d(StartLoc, PlayerLoc)
				
				if SquareDistance > Module.MaximumTeamSpawnSqDistance then
					return true
				end
			end
			
			return false
		end)
end

function Module.MediumEnemyDistanceFilter(Player, PlayerStarts)
	return FilterOnRejectCondition(Player, PlayerStarts, function(SpawningPlayer, OtherPlayer, PlayerStart)
		local StartLoc = PlayerStart:GetLocation()

		local SpawnerTeam = Moon.Team.GetPlayersTeam(SpawningPlayer)
		local CheckAgainstTeam = Moon.Team.GetPlayersTeam(OtherPlayer)
		
		local ValidPawn = OtherPlayer:IsAlive()
		local DifferentPlayer = OtherPlayer:GetName() ~= SpawningPlayer:GetName()
		local SameTeam = SpawnerTeam ~= nil 
			and CheckAgainstTeam ~= nil 
			and SpawnerTeam:GetName() == CheckAgainstTeam:GetName()
		
		if ValidPawn and DifferentPlayer and SameTeam == false then
			local PlayerLoc = OtherPlayer:GetLocation()
			local SquareDistance = Math.SquaredDist3d(StartLoc, PlayerLoc)
			
			InMediumDist = SquareDistance < Module.MediumMaxDist and SquareDistance > Module.MediumMinDist
			if InMediumDist == false then
				return true
			end
		end
		
		return false
	end)
end

function Module.TryMakeSpawnPointNear(Location, Player, Range)
	local Spot = Unreal.Navigation.FindNavigablePosition(Location, Range, Player)

	if Spot[1] then
		Spot[2].Z = Spot[2].Z + 200        
		return Unreal.PlayerStart.MakeStart("SpawnPoint", Spot[2])
	end

	return nil
end

-- ModuleScripts must return exactly one value
return Module