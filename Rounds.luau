local Module = {}

local globalprint = print
print = function (...)
	globalprint("RoundsModule: ", ...)
end

--Configure Game Mode
local GameMode = Moon.GameMode.First()
local ScriptTuner = Moon.ScriptTuner.GetOrMake()

Module.RoundCount = ScriptTuner:GetInt("GameRules/RoundLimit", 3)
Module.RoundLength =  ScriptTuner:GetInt("GameRules/RoundDuration", 5) * 60
Module.RoundResetTimer = 10
Module.EndRoundMessageTime = 10

local CurrentRound = 0

function Module.GetCurrentRound()
	return CurrentRound
end

Module.RoundState = {}
Module.RoundState.MidRound = 1
Module.RoundState.BetweenRounds = 2
Module.RoundState.MatchOver = 3
local CurrentRoundState = Module.RoundState.BetweenRounds

function Module.GetRoundState()
	return CurrentRoundState
end

local MatchEndCallback = nil
local RoundEndCallback = nil
local NewRoundCallback = nil
local RoundEndMessage = nil

local ScoreUISettings = Moon.ScoreUISettings.Get() 

function Module.SetOnNewRound(OnNewRoundCallback)
	NewRoundCallback = OnNewRoundCallback
end

function Module.SetOnRoundEnd(OnRoundEndCallback)
	RoundEndCallback = OnRoundEndCallback
end

function Module.SetOnMatchEnd(OnMatchEndCallback)
	MatchEndCallback = OnMatchEndCallback
end

function Module.SetOnRoundEndMessage(OnRoundEndMessage)
	RoundEndMessage = OnRoundEndMessage
end

local EndRoundTimerHandle = nil

function EndRoundInternal()
	print("Round Ended")
	CurrentRoundState = Module.RoundState.BetweenRounds

	if RoundEndCallback ~= nil then
		RoundEndCallback()
	end

	if EndRoundTimerHandle ~= nil then
		MS.Utility.ClearTimer(EndRoundTimerHandle)
		EndRoundTimerHandle = nil
	end

	if CurrentRound == Module.RoundCount then
		MatchEnd()
	else
		MS.Utility.SetTimer(NewRound, Module.RoundResetTimer + Module.EndRoundMessageTime)

		if RoundEndMessage ~= nil then
			Moon.MessageController.Get():SendMessageToAll(RoundEndMessage(), Module.EndRoundMessageTime)
		end

		MS.Utility.SetTimer(function ()
			Moon.MessageController.Get():SendMessageToAll("Next round starting in", Module.RoundResetTimer, true)
		end, Module.EndRoundMessageTime)	
	end
end

function NewRound()
	print("Round Started")
	CurrentRoundState = Module.RoundState.MidRound
	CurrentRound = CurrentRound + 1
	ScoreUISettings.RoundName = "Round " .. tostring(CurrentRound)
	if NewRoundCallback ~= nil then
		NewRoundCallback()
	end

	EndRoundTimerHandle = MS.Utility.SetTimer(EndRoundInternal, Module.RoundLength)
	GameMode:SetMatchClock(Module.RoundLength)
end

function MatchEnd()
	print("Match Ended")
	CurrentRoundState = Module.RoundState.MatchOver
	if MatchEndCallback ~= nil then
		MatchEndCallback()
	end
end

function Module.EndCurrentRound()
	EndRoundInternal()
end

function Module.Start()
	NewRound()
end

print("Loading")

-- ModuleScripts must return exactly one value
return Module