local _, GF = ...

GF.NavCatalog = {}

local NC = GF.NavCatalog

local function catalog()
	return GF.NAV_CATALOG
end

function NC.GetMeta(kind)
	local cat = catalog()
	return cat and cat[kind]
end

function NC.GetExpansions(kind)
	local meta = NC.GetMeta(kind)
	if not meta or not meta.expansions then
		return {}
	end
	return meta.expansions
end

function NC.GetInstances(kind, expansionIndex)
	for _, exp in ipairs(NC.GetExpansions(kind)) do
		if exp.expansionIndex == expansionIndex then
			return exp.instances or {}
		end
	end
	return {}
end

function NC.CollectGroupIDs(kind)
	local seen = {}
	local out = {}
	for _, exp in ipairs(NC.GetExpansions(kind)) do
		for _, inst in ipairs(exp.instances or {}) do
			local gid = inst.groupID
			if gid and not seen[gid] then
				seen[gid] = true
				out[#out + 1] = gid
			end
		end
	end
	table.sort(out)
	return out
end
