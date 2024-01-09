local Module = {}

math.randomseed(os.time())

local function Log(text)
	MS.Utility.Log("MathModule: " .. text)
end

MS.Utility.Log("Loading Math.luau!")

function Module.SquaredDist3d(Vector1, Vector2)
	return (Vector2.X - Vector1.X)^2 + (Vector2.Y - Vector1.Y)^2 + (Vector2.Z - Vector1.Z)^2
end

function Module.RandomLocationWithinDistance(Location, Distance)
	local XOffset = math.random(-1 * Distance, Distance)
	local YOffset = math.random(-1 * Distance, Distance)
	local ZOffset = math.random(-1 * Distance, Distance)

	local Result = {X=(Location.X + XOffset), Y=(Location.Y + YOffset), Z=(Location.Z + ZOffset)}
	return Result
end

-- ModuleScripts must return exactly one value
return Module