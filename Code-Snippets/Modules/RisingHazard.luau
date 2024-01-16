local Module = {}

MS.Utility.Log("Loading RisingHazard.luau!")

-- Following values are default behavior is desired.
-- Alternative values can be provided prior to calling initialize to customize behavior
Module.StartTime = 5.0
Module.StartElevation = -10500.0
Module.EndTime = 960.0
Module.EndElevation = 550.0

function Module.Start()
	local Hazard = Moon.RisingHazard.First()
	Hazard:SetEnabled(true, 0.0)
end

function Module.Initialize()
	local Hazard = Moon.RisingHazard.First()

	Hazard:SetStartTime(Module.StartTime)
	Hazard:SetStartElevation(Module.StartElevation)
	Hazard:SetEndTime(Module.EndTime)
	Hazard:SetEndElevation(Module.EndElevation)
	
	Hazard.EnablePlayerStartFilter = true
end

-- ModuleScripts must return exactly one value
return Module