local Inventory = require("Modules/Inventory")
local MidnightUtility = require("Modules/MidnightUtility")

-- Tables store multiple values in one variable
local Module = {}

MS.Utility.Log("Loading GunGame_WeaponCycles.luau!")

Module.WeaponCycles = {}

local Sniper = { 
	Weapon="SniperRifle", 
	Parts={"SniperRifleBarrel_B", "SniperRifleChip_B", "SniperRifleGrip_B", "SniperRifleStock_B", "8xPTS-2"}
}

local AssaultRifle = { 
	Weapon="AssaultRifle", 
	Parts={"3xReflex-1"}
}

local Shotgun = { 
	Weapon="RangeShotgun", 
	Parts={}
}

local HeavyPistol = { 
	Weapon="HeavyPistol", 
	Parts={}
}

local DeepFreezeSMG = { 
	Weapon="DeepFreezeSMG", 
	Parts={"3xReflex-1"}
}

local DeepFreezeShotgun = { 
	Weapon="DeepFreezeShotgun", 
	Parts={}
}

local Pistol = { 
	Weapon="AutoPistol", 
	Parts={}
}

local LMG = { 
	Weapon="LMG", 
	Parts={"3xReflex-1"}
}

local BurstPistol = { 
	Weapon="BurstPistol", 
	Parts={"8xPTS-2"}
}

local SemiPistol = { 
	Weapon="SemiPistol", 
	Parts={"8xPTS-2"}
}

local DMR = { 
	Weapon="DMR", 
	Parts={"4xPTS-1"}
}

local DoubleBarrel = { 
	Weapon="DoubleBarrel", 
	Parts={}
}


local Knife = { 
	Weapon="Knife", 
	Parts={}
}

function EmptyTable (table)
	if table == nil then 
		return true 
	end

    for _, _ in pairs(table) do
        return false
    end
    return true
end

local CurrentIndexMap = MidnightUtility.MidnightTable.New()

function Module.TryGrantCycleWeapon(Player, Cycle, GoForward)
	
	if CurrentIndexMap[Player] == nil then
		CurrentIndexMap[Player] = 1
	else
		if GoForward == true then
			CurrentIndexMap[Player] = CurrentIndexMap[Player] + 1
		elseif CurrentIndexMap[Player] > 1 then
			CurrentIndexMap[Player] = CurrentIndexMap[Player] - 1
		end
	end

	if CurrentIndexMap[Player] > #Cycle then
		return CurrentIndexMap[Player]
	end

	Inventory.GrantWeapon(Player, Cycle[CurrentIndexMap[Player]], true, true)

	return CurrentIndexMap[Player]
end

function Module.GetCurrentWeaponIndex(Player)
	if CurrentIndexMap[Player] == nil then
		return 0
	end
	
	return  CurrentIndexMap[Player]
end

function Module.MakeCycle()
	return {Sniper, AssaultRifle, HeavyPistol, DeepFreezeSMG, DeepFreezeShotgun, Pistol, LMG, DMR, DoubleBarrel, BurstPistol, Shotgun, Knife}
end

-- ModuleScripts must return exactly one value
return Module