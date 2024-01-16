local Module = {}
MS.Utility.Log("Loading ExtractionManager.luau!")

function Module.Initialize()
	local ExtractionManager = Moon.ExtractionManager.First()
	ExtractionManager:SetEnabled(true)
end

-- ModuleScripts must return exactly one value
return Module