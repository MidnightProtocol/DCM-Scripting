MidnightUtility = require("Modules/MidnightUtility")

local Module = {}

local globalprint = print
print = function (...)
	globalprint("EffectsModule: ", ...)
end

local ScriptTuner = Moon.ScriptTuner.GetOrMake()

local HealthRegenType = ScriptTuner:GetString("Health/HealthRegen", "Normal");
local HealthModifierScalar = ScriptTuner:GetFloat("Health/Health", 1.0);

local HealthRegenSpeed = 0;

if HealthRegenType == "Normal" then
	HealthRegenSpeed = .1;
elseif HealthRegenType == "Slow" then
	HealthRegenSpeed = .2;
elseif HealthRegenType == "Fast" then
	HealthRegenSpeed = .05;
end

-- Start player Health Regen
-- SetHealthRegenEffect to modify the effect from defaults
-- AddHealthRegen to give the effect to a player
-- RemoveHealthRegen to remove the effect from a player
local HealthRegenEffect = nil


local HealthModifierEffect = Moon.GameplayEffect.CreateEffect("Multiply", 0)
HealthModifierEffect:SetMagnitude("MaxHealth", HealthModifierScalar)

if HealthRegenSpeed > 0 then
	HealthRegenEffect = Moon.GameplayEffect.CreateEffect("Additive", HealthRegenSpeed)
	HealthRegenEffect:SetMagnitude("Health", 1)
end

local PostDamageToHealTime = ScriptTuner:GetInt("Health/HealthRegenDelay", 5)

function Module.SetHealthRegenEffect(HealInterval: number, HealAmount: number, DamageToHealTime: number)
	HealthRegenEffect = Moon.GameplayEffect.CreateEffect("Additive", HealInterval)
	HealthRegenEffect:SetMagnitude("Health", HealAmount)
	
	PostDamageToHealTime = DamageToHealTime
end

local RegenEffects = {
	ActiveEffectHandles = MidnightUtility.MidnightTable.New(),
	ActiveTimerHandles = MidnightUtility.MidnightTable.New()
}

local GameMode = Moon.GameMode.First()

if(HealthModifierScalar ~= 1.0) then
	GameMode.OnRespawn:Connect(function(Player)	
		MS.Utility.Log("Applied Health Modifier")
		Moon.GameplayEffect.ApplyEffect(Player, HealthModifierEffect)
	end)
end

function ApplyRegenWithDelay(Context)
	local Player = Moon.Player.Cast(Context)
	if Player ~= nil and Player:IsAlive() and HealthRegenEffect ~=nil then
		MS.Utility.Log("ApplyRegenWithDelay")
		RegenEffects.ActiveEffectHandles[Player] = Moon.GameplayEffect.ApplyEffect(Player, HealthRegenEffect)
	end
end

function ClearEffectAndTimer(Player)
	if RegenEffects.ActiveEffectHandles[Player] ~= nil then
		Moon.GameplayEffect.RemoveEffect(Player, RegenEffects.ActiveEffectHandles[Player])
		RegenEffects.ActiveEffectHandles[Player] = nil
	end
	
	if RegenEffects.ActiveTimerHandles[Player] ~= nil then 
		MS.Utility.ClearTimer(RegenEffects.ActiveTimerHandles[Player])
		RegenEffects.ActiveTimerHandles[Player] = nil
	end
end

function PlayerHealthChanged(Player, OldHealth, NewHealth)
	local PlayerAttributes = Player:GetAttributes()

	if PlayerAttributes:GetHealth() >= PlayerAttributes:GetMaxHealth() then
		ClearEffectAndTimer(Player)
	end

	if NewHealth < OldHealth then 
		ClearEffectAndTimer(Player)
		
		RegenEffects.ActiveTimerHandles[Player] = MS.Utility.SetTimerWithContext(ApplyRegenWithDelay, PostDamageToHealTime, Player)
	end
end

function Module.AddHealthRegen(Player)
	if HealthRegenEffect ~= nil then 
		Player.OnHealthChanged:Connect(PlayerHealthChanged)
	end
end

function Module.RemoveHealthRegen(Player)
	if HealthRegenEffect ~= nil then 
		Player.OnHealthChanged:Remove(PlayerHealthChanged)
		ClearEffectAndTimer(Player)
	end
end

function Module.TuneHealthRegen(TimeToStartHeal, Interval)
	PostDamageToHealTime = TimeToStartHeal
	HealthRegenSpeed = Interval
end
-- End Player health Regen

print("Loading")

-- ModuleScripts must return exactly one value
return Module


--[[
Currently Available Attributes (Depends on being added to AttributeMapping in MoonAbilitySystemGlobals)
	-"Health"
	-"MaxHealth"
	-"MoveSpeed"
	-"Stamina"
	-"MaxStamina"
	-"StaminaRegen"
	-"Armor"
		
Effect types available to CreateEffect
	-Additive
	-Multiply
		 		 
Usage

--This function is used to create an infinite gameplay effect that can have it's modifiers reapplied periodically 

	Moon.GameplayEffect.CreateEffect(
			GameMode,
			EffectType ("Additive", "Multiply"),
			RepeatTimer (0 = one time application, > 0 modifiers will be reapplied periodically until effect is removed)
		)
	
--This function is used to modify a single attribute's base value by some magnitude and operation

	Moon.GameplayEffect.SetMagnitude(
			Effect Handle (from CreateEffect),
			AttributeName,
			Magnitude
		)
		
--Use this function to apply an existing effect to a pawn	
	ApplyEffect(
		Pawn, 
		Handle (From Create Effect)
	)
	
--Use this function to remove an existingi effect from a pawn using the handle returned by ApplyEffect
	RemoveEffect(
		Pawn,
		Handle (From Apply Effect)
	)
	
--Used to permanently override the base value of an attribute. This uses an instant effect and provides no handle	
	OverrideAttributeBaseValue(
	Pawn, 
	AttributeName, 
	Magnitude
	);
	
--Used to return all attributes within an attribute set back to their default values
	ResetAttributeSetBaseValue(
	Pawn, 
	AttributeSet
	);
	
--Used to return a single attribute in a set back to it's default value
	ResetAttributeBaseValue(
	Pawn, 
	AttributeSet, 
	AttributeName
	);
]]--