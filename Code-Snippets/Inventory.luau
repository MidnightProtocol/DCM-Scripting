local Module = {}

local function Log(text)
	MS.Utility.Log("InventoryModule: " .. text)
end

MS.Utility.Log("Loading Inventory.luau!")

function Module.GrantStack(Container, Stackable)
	Log("Granting stack: " .. Stackable)
	Container:AddItem(Stackable, function(NewObject) 
		NewObject:SetStackCount(NewObject.MaxStackCount)	
	end)
end

local function AttachPart(Container, Weapon, Part)
	MS.Utility.Log("AttachPart: Attaching part " .. Part)
	Container:AddItem(Part, function(NewObject)
		local NewPart = Moon.InventoryItemInstance_WeaponPart.Cast(NewObject)
		if NewPart ~= nil then
			Log(NewPart:GetName())
			Weapon:TryAttachWeaponPart(NewPart)
		end
	end)
end

function Module.GrantWeapon(Player, Weapon, MoveToEquipment, AutoEquip)
	Log("Granting weapon: " .. Weapon.Weapon)

	local Container = nil
	
	if MoveToEquipment == true then
		Container = Player:GetEquipment()
	else
		Container = Player:GetBackpack()
	end

	Container:AddItem(Weapon.Weapon, function(NewObject)
		local NewWeapon = Moon.InventoryItemInstance_Weapon.Cast(NewObject)
		if NewWeapon ~= nil then
			for k,v in pairs(Weapon.Parts) do
				Log("Granting part" .. v)
				AttachPart(Player:GetBackpack(), NewWeapon, v)
			end		
		end
	end, AutoEquip)
end

function Module.GrantStackBlocking(Player, Stackable)
	Log("Granting stack: " .. Stackable)
	Container:AddItemBlocking(Stackable, function(NewObject) 
		NewObject:SetStackCount(NewObject.MaxStackCount)	
	end)
end

function Module.GrantWeaponBlocking(Player, Weapon)
	Log("Granting weapon: " .. Weapon.Weapon)

	Player:GetEquipment():AddItemBlocking(Weapon.Weapon, function(NewObject)
		local NewWeapon = Moon.InventoryItemInstance_Weapon.Cast(NewObject)
		
		if NewWeapon ~= nil then
			for k,v in pairs(Weapon.Parts) do
				Log("Granting part" .. v)
				AttachPart(Container, NewWeapon, v)
			end		
		end
	end)
end


-- ModuleScripts must return exactly one value
return Module