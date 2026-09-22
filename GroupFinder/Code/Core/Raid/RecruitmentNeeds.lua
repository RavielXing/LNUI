local _, GF = ...

-- Public class metadata and the local raid-form selection. These preferences
-- are not parameters accepted by Blizzard's listing API.
local Needs = {}
GF.RaidRecruitmentNeeds = Needs

function Needs:GetCatalog()
	if self.catalog then return self.catalog end
	local specAPI = C_SpecializationInfo
	if type(GetNumClasses) ~= "function" or type(GetClassInfo) ~= "function"
		or type(GetSpecializationInfoForClassID) ~= "function"
		or not specAPI or type(specAPI.GetNumSpecializationsForClassID) ~= "function"
	then
		return {}
	end
	local ok, count = pcall(GetNumClasses)
	if not ok or type(count) ~= "number" or count < 1 then return {} end
	local catalog, complete = {}, true
	for classIndex = 1, count do
		local classOK, name, token, classID = pcall(GetClassInfo, classIndex)
		if classOK and type(name) == "string" and type(token) == "string"
			and type(classID) == "number"
		then
			local row = { classID = classID, name = name, classFile = token, specs = {} }
			local countOK, specCount = pcall(specAPI.GetNumSpecializationsForClassID, classID)
			if countOK and type(specCount) == "number" and specCount > 0 then
				for specIndex = 1, specCount do
					local specOK, id, specName, _, icon, role =
						pcall(GetSpecializationInfoForClassID, classID, specIndex)
					if specOK and type(id) == "number" and id > 0
						and type(specName) == "string" and icon ~= nil
					then
						-- The seventh native result is allowedForBoost, not
						-- availability for recruitment. Include every valid spec.
						row.specs[#row.specs + 1] = {
							id = id, name = specName, icon = icon, role = role,
						}
					else
						complete = false
					end
				end
			else
				complete = false
			end
			if #row.specs > 0 then catalog[#catalog + 1] = row end
		else
			complete = false
		end
	end
	-- A transiently missing class/spec must not become a permanent empty row.
	if complete and #catalog > 0 then self.catalog = catalog end
	return catalog
end

function Needs:CopySelection(selected)
	local copy = {}
	for id, enabled in pairs(type(selected) == "table" and selected or {}) do
		if type(id) == "number" and id > 0 and id % 1 == 0 and enabled == true then
			copy[id] = true
		end
	end
	return copy
end

-- nil is a fresh, unrestricted draft; an explicit empty table blocks every
-- spec. Resolve lazily so a temporarily missing catalog cannot freeze defaults.
function Needs:ResolveSelection(selected)
	if selected ~= nil then return self:CopySelection(selected) end
	local all = {}
	for _, row in ipairs(self:GetCatalog()) do
		for _, spec in ipairs(row.specs) do all[spec.id] = true end
	end
	return all
end

function Needs:GetRoleCounts(selected)
	local counts = {
		TANK = { selected = 0, total = 0 },
		HEALER = { selected = 0, total = 0 },
		DAMAGER = { selected = 0, total = 0 },
	}
	for _, row in ipairs(self:GetCatalog()) do
		for _, spec in ipairs(row.specs) do
			local count = counts[spec.role]
			if count then
				count.total = count.total + 1
				if selected == nil or selected[spec.id] == true then
					count.selected = count.selected + 1
				end
			end
		end
	end
	return counts
end

function Needs:SetRoleSelected(selected, role, enabled)
	local copy = self:ResolveSelection(selected)
	for _, row in ipairs(self:GetCatalog()) do
		for _, spec in ipairs(row.specs) do
			if spec.role == role then copy[spec.id] = enabled == true and true or nil end
		end
	end
	return copy
end

function Needs:IsAvailableSpec(specID)
	for _, row in ipairs(self:GetCatalog()) do
		for _, spec in ipairs(row.specs) do
			if spec.id == specID then return true end
		end
	end
	return false
end
