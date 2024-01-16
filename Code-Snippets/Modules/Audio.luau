local Module = {}

local globalprint = print
print = function (...)
	globalprint("AudioModule: ", ...)
end

type SoundRequestType = {
	Sound: string, 
	Attenuation: string?, 
	Location: {X: number, Y: number, Z: number}?,
	VolumeMultiplier: number?,
	PitchMultiplier: number?}

local DefaultRequest = {
	Sound = "Test",
	Attenuation = "None",
	Location = {X=0,Y=0,Z=0},
	VolumeMultiplier=1,
	PitchMultiplier=1
}

function LoadRequest (lookup, defaults)
	local mt = { __index = function(Table, Key)
		if lookup[Key] == nil then
			return defaults[Key]
		end

		return lookup[Key]
	end}

	local Result = {}
	setmetatable(Result, mt)
	return Result
end

function Module.PlayGlobalSound(Request: SoundRequestType)
	local LocalRequest = LoadRequest(Request, DefaultRequest)
	Moon.AudioController.PlayGlobalSound(LocalRequest)
end

function Module.PlaySoundForPlayer(Request: SoundRequestType, Player)
	local LocalRequest = LoadRequest(Request, DefaultRequest)
	Moon.AudioController.PlaySound(LocalRequest, Player)
end

function Module.PlaySoundForPlayers(Request: SoundRequestType , Players)
	local LocalRequest = LoadRequest(Request, DefaultRequest)
	Moon.AudioController.PlaySound(LocalRequest, Players)
end


--Tags
local Sounds = {}
Sounds.Alarm = "Audio.Alarm"
Sounds.LargeEnderOne = "Audio.LargeEnder.One"
Sounds.ActivateA = "Audio.Activate.A"
Sounds.LargeObjectiveOne = "Audio.ObjLarge.One"
Sounds.LargeObjectiveThree = "Audio.ObjLarge.Three"
Sounds.TechStingerThree = "Audio.TechStinger.Three"
Sounds.TechStingerOne = "Audio.TechStinger.One"
Module.Sound = Sounds

local Attenuations = {}
Attenuations.Short = "Audio.Attenuation.Short"
Attenuations.Medium = "Audio.Attenuation.Medium"
Attenuations.Large = "Audio.Attenuation.Large"
Module.Attenuation = Attenuations


print("Loading")

-- ModuleScripts must return exactly one value
return Module