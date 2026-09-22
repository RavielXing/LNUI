local _, GF = ...

local Service = GF.SpecializationInfo or {}
GF.SpecializationInfo = Service

local function isAccessible(value)
	if value == nil then
		return true
	end
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if ok and accessible == false then
			return false
		end
	end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if ok and secret == true then
			return false
		end
	end
	return true
end

local function safeNumber(value)
	if value == nil or not isAccessible(value) then
		return nil
	end
	local ok, numeric = pcall(tonumber, value)
	return ok and numeric or nil
end

local function safeString(value)
	if value == nil or not isAccessible(value) then
		return nil
	end
	return type(value) == "string" and value or nil
end

local function normalizeRole(role)
	role = safeString(role)
	if not role then
		return nil
	end
	local ok, normalized = pcall(string.upper, role)
	if not ok then
		return nil
	elseif normalized == "HEAL" then
		return "HEALER"
	elseif normalized == "DPS" then
		return "DAMAGER"
	elseif normalized == "TANK"
		or normalized == "HEALER"
		or normalized == "DAMAGER"
	then
		return normalized
	end
	return nil
end

function Service.GetCurrentSpecializationIndex()
	local api = C_SpecializationInfo
	local getter = type(api) == "table" and api.GetSpecialization or nil
	if type(getter) ~= "function" then
		return nil, "unavailable"
	end
	local ok, rawIndex = pcall(getter)
	if not ok then
		return nil, "error"
	elseif not isAccessible(rawIndex) then
		return nil, "secret"
	end
	local specIndex = safeNumber(rawIndex)
	if not specIndex or specIndex <= 0 then
		return nil, "unavailable"
	end
	return specIndex, "ready"
end

function Service.GetCurrentSnapshot()
	local snapshot = { state = "unavailable" }
	local specIndex, indexState = Service.GetCurrentSpecializationIndex()
	if not specIndex then
		snapshot.state = indexState
		return snapshot
	end
	snapshot.specIndex = specIndex

	local api = C_SpecializationInfo
	local getter = type(api) == "table" and api.GetSpecializationInfo or nil
	if type(getter) ~= "function" then
		return snapshot
	end
	local ok, rawID, rawName, _, rawIcon, rawRole = pcall(
		getter,
		specIndex
	)
	if not ok then
		snapshot.state = "error"
		return snapshot
	end

	local specID = safeNumber(rawID)
	if specID and specID > 0 then
		snapshot.specID = specID
		snapshot.state = "ready"
	elseif not isAccessible(rawID) then
		snapshot.state = "secret"
	end
	snapshot.specName = safeString(rawName)
	if isAccessible(rawIcon) then
		snapshot.specIcon = rawIcon
	end
	snapshot.specRole = normalizeRole(rawRole)

	-- GetSpecializationInfo supplies the role on supported Retail clients.  Keep
	-- the established role helper only as a narrow fail-open fallback if that
	-- field is temporarily unavailable during login or specialization changes.
	if not snapshot.specRole and type(GetSpecializationRole) == "function" then
		local roleOK, fallbackRole = pcall(GetSpecializationRole, specIndex)
		if roleOK then
			snapshot.specRole = normalizeRole(fallbackRole)
		end
	end
	return snapshot
end

function Service.GetInspectSpecialization(unit)
	local api = C_SpecializationInfo
	local getter = type(api) == "table"
		and api.GetInspectSpecialization or nil
	-- Retail 12.0.7 does not expose the namespaced inspect function.  Keep this
	-- capability fallback only while the TOC still supports that interface.
	if type(getter) ~= "function" then
		getter = type(_G.GetInspectSpecialization) == "function"
			and _G.GetInspectSpecialization or nil
	end
	if type(getter) ~= "function" then
		return nil, "unavailable"
	end
	local ok, rawID = pcall(getter, unit)
	if not ok then
		return nil, "error"
	elseif not isAccessible(rawID) then
		return nil, "secret"
	end
	local specID = safeNumber(rawID)
	if not specID or specID <= 0 then
		return nil, "unavailable"
	end
	return specID, "ready"
end
