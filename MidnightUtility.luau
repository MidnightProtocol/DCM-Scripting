local Module = {}

local globalprint = print
print = function (...)
	globalprint("MidnightUtilityModule: ", ...)
end

print("Loading")

local MetaMidnightTable = {}

MetaMidnightTable.__newindex = function(t, k, v)
	if k == nil then
		print("Attempted to use nil as key")
		return rawget(t, k)
	end
	
	if k.GetName ~= nil then
		t[k:GetName()] = v
	else
		return rawset(t, k, v)
	end
end

MetaMidnightTable.__index = function(t, k)
	if k == nil then
		print("Attempted to use nil as key")
		return rawget(t, k)
	end
	
	if k.GetName ~= nil then
		return t[k:GetName()]
	else
		return rawget(t, k)
	end
end



Module.MidnightTable = {}

function Module.MidnightTable.New()
	ReturnTable = {}
	setmetatable(ReturnTable, MetaMidnightTable)
	return ReturnTable
end

function Equal(p1, p2) 
	if p1.GetName ~= nil and p2.GetName ~= nil then
		return p1:GetName() == p2:GetName()
	else
		return p1 == p2
	end
end

function Module.TableFind(tab,el)
	for index, value in pairs(tab) do
		if Equal(value, el) then
			return index
		 end
	end
end

function Module.Shuffle(tbl)
	for i = #tbl, 2, -1 do
	  local j = math.random(i)
	  tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
  end

return Module