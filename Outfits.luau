MidnightUtility = require("MidnightUtility")

local Module = {}

local globalprint = print
print = function (...)
	globalprint("OutfitsModule: ", ...)
end

local Keys = {"Kassius", "Pixel", "Syn"}

local Tags = {}
Tags.Kassius = "Outfit.Kassius"
Tags.Fender = "Outfit.Fender"
Tags.FenderVariant = "Outfit.FenderVariant"
Tags.Syn = "Outfit.Syn"
Tags.Infected = "Outfit.Infected"
Tags.Pixel = "Outfit.Pixel"

Tags.CleanersVendor = "Outfit.Cleaner.Vendor"
Tags.CleanersHarvester = "Outfit.Cleaner.Harvester"
Tags.CleanersGuard = "Outfit.Cleaner.Guard"
Tags.CleanersScout = "Outfit.Cleaner.Scout"

Module.Outfits = Tags

function Module.SetOutfit(Player, Outfit)
	local OutfitController = Player:GetOutfitController()
	OutfitController:SetOutfit(Outfit)
end

math.randomseed(os.time())

function Module.SetRandomOutfit(Player)
	local OutfitController = Player:GetOutfitController()
	OutfitController:SetOutfit(Tags[Keys[math.random(1,#Keys)]])
end

print("Loading")

-- ModuleScripts must return exactly one value
return Module

