local MidnightUtility = require("MidnightUtility")

local Module = {}

local globalprint = print
print = function (...)
	globalprint("TaggingModule: ", ...)
end

print("Loading")

local TagMap = MidnightUtility.MidnightTable.New()

function Module.AddTag(Target, Tag)
	if not TagMap[Target] then
		TagMap[Target] = {}
	end
	
	if not TagMap[Target].AddedTag then
		TagMap[Target].AddedTag = {}
	end
	
	TagMap[Target].AddedTag[Tag] = Tag
	
	if TagMap[Target].RemovedTag then
		TagMap[Target].RemovedTag[Tag] = nil
	end
end

function Module.RemoveTag(Target, Tag)
	if not TagMap[Target] then
		TagMap[Target] = {}
	end
	
	if not TagMap[Target].RemovedTag then
		TagMap[Target].RemovedTag = {}
	end
	
	TagMap[Target].RemovedTag[Tag] = Tag
		
	if TagMap[Target].AddedTag then
		TagMap[Target].AddedTag[Tag] = nil
	end
end

function Module.HasTag(Target, Tag)
	if TagMap[Target] then	
		if TagMap[Target].AddedTag then
			local HasLuaTag = TagMap[Target].AddedTag[Tag] ~= nil 
			
			if HasLuaTag then
				return true
			end
		end
		
		if TagMap[Target].RemovedTag then
			local ContainsRemovedTag = TagMap[Target].RemovedTag[Tag] ~= nil
			if ContainsRemovedTag then
				return false
			end
		end
	end
	
	if Target.HasTag ~= nil then
		return Target:HasTag(Tag)
	end
	
	return false
end

function Module.FilterByTag(Actors, Tag)
	local ActorsOut = {}
	
	for i = 1, #Actors do
		if Module.HasTag(Actors[i], Tag) then
			table.insert(ActorsOut, Actors[i])
		end
	end
	
	return ActorsOut
end

return Module