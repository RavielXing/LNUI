local _, GF = ...

GF.MythicPlusServiceUtil = GF.MythicPlusServiceUtil or {}
local Util = GF.MythicPlusServiceUtil

Util.ROLE_ORDER = { "TANK", "HEAL", "DPS" }

function Util.Now()
	return time and time() or 0
end

function Util.GetLastWeeklyResetTimestamp()
	if C_DateAndTime and C_DateAndTime.GetWeeklyResetStartTime then
		local ok, resetTime = pcall(C_DateAndTime.GetWeeklyResetStartTime)
		if ok and type(resetTime) == "number" and resetTime > 0 then
			return resetTime
		end
	end
	if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
		local ok, seconds = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
		if ok and type(seconds) == "number" and seconds > 0 then
			return Util.Now() + seconds - (7 * 24 * 60 * 60)
		end
	end
	return 0
end

function Util.Trim(value)
	if type(value) ~= "string" then
		return nil
	end
	value = value:gsub("^%s+", ""):gsub("%s+$", "")
	return value ~= "" and value or nil
end

function Util.TruncateUtf8(value, maxBytes)
	value = tostring(value or "")
	maxBytes = math.floor(tonumber(maxBytes) or 0)
	if maxBytes <= 0 then
		return ""
	end
	if #value <= maxBytes then
		return value
	end
	local lastValidEnd = 0
	local index = 1
	while index <= #value do
		local byte = value:byte(index)
		local charBytes = 1
		if byte >= 240 then
			charBytes = 4
		elseif byte >= 224 then
			charBytes = 3
		elseif byte >= 192 then
			charBytes = 2
		end
		if index + charBytes - 1 > maxBytes then
			break
		end
		if index + charBytes - 1 > #value then
			charBytes = 1
		end
		lastValidEnd = index + charBytes - 1
		index = index + charBytes
	end
	return value:sub(1, lastValidEnd)
end

function Util.NormalizeName(value)
	value = Util.Trim(value)
	if not value then
		return nil
	end
	value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	value = value:gsub("%s*[-–—]%s*[^-–—]+$", "")
	value = value:gsub("[%s%p%c]+", "")
	value = value:gsub("[：:（）()%[%]【】「」『』《》〈〉、，。；;！!？?%-_—–·]+", "")
	return value ~= "" and string.lower(value) or nil
end

function Util.CopyArray(source)
	local out = {}
	for i, value in ipairs(source or {}) do
		out[i] = value
	end
	return out
end

function Util.CopyRuns(source)
	local out = {}
	for _, run in ipairs(source or {}) do
		out[#out + 1] = {
			mapID = tonumber(run.mapID or run.challengeModeID or run.mapChallengeModeID),
			level = tonumber(run.level or run.bestRunLevel) or 0,
			score = tonumber(run.score or run.mapScore or run.runScore) or 0,
			scoreColor = type(run.scoreColor) == "table" and {
				r = tonumber(run.scoreColor.r) or 1,
				g = tonumber(run.scoreColor.g) or 1,
				b = tonumber(run.scoreColor.b) or 1,
				a = tonumber(run.scoreColor.a) or 1,
			} or nil,
			durationMS = tonumber(run.durationMS or run.bestRunDurationMS)
				or ((tonumber(run.durationSec) or 0) * 1000),
			timed = run.timed == true or run.finishedSuccess == true,
		}
	end
	return out
end

function Util.NormalizeRole(role)
	if role == "TANK" then
		return "TANK"
	end
	if role == "HEALER" or role == "HEAL" then
		return "HEAL"
	end
	if role == "DAMAGER" or role == "DPS" then
		return "DPS"
	end
	return nil
end

function Util.CopyRoles(source, fallbackRole)
	local roles = {}
	if type(source) == "table" then
		for key, value in pairs(source) do
			local role = type(key) == "number" and value or key
			local enabled = type(key) == "number" or value == true
			local normalized = enabled and Util.NormalizeRole(role) or nil
			if normalized then
				roles[normalized] = true
			end
		end
	end
	if not next(roles) then
		local normalized = Util.NormalizeRole(fallbackRole)
		if normalized then
			roles[normalized] = true
		end
	end
	return roles
end

function Util.CopyRoleFlags(source)
	local roles = Util.CopyRoles(source)
	return {
		TANK = roles.TANK == true,
		HEAL = roles.HEAL == true,
		DPS = roles.DPS == true,
	}
end

function Util.FirstRole(roles)
	for _, role in ipairs(Util.ROLE_ORDER) do
		if roles and roles[role] == true then
			return role
		end
	end
	return nil
end

function Util.RolesEqual(left, right)
	for _, role in ipairs(Util.ROLE_ORDER) do
		if (left and left[role] == true or false)
			~= (right and right[role] == true or false)
		then
			return false
		end
	end
	return true
end

function Util.NormalizeSpecialization(character)
	if type(character) ~= "table" then
		return character
	end
	local cache = GF.MythicPlusSpecializationCache
	if cache and cache.NormalizeCharacter then
		cache:NormalizeCharacter(character)
	end
	return character
end

function Util.AddListener(owner, callback)
	if type(callback) ~= "function" then
		return
	end
	owner.listeners = owner.listeners or {}
	owner.listeners[#owner.listeners + 1] = callback
end

function Util.Notify(owner, reason)
	for _, callback in ipairs(owner.listeners or {}) do
		pcall(callback, owner, reason)
	end
end

function Util.GetUnitFullName(unit)
	if not (UnitExists and UnitExists(unit)) then
		return nil, nil, nil
	end
	local name
	local realm
	if UnitFullName then
		name, realm = UnitFullName(unit)
	end
	if not name or name == "" then
		name = UnitName and UnitName(unit)
	end
	if not name or name == "" then
		return nil, nil, nil
	end
	if not realm or realm == "" then
		realm = GetRealmName and GetRealmName() or ""
	end
	local fullName = realm ~= "" and (name .. "-" .. realm) or name
	return fullName, name, realm
end

function Util.GetUnitKey(unit)
	local guid = UnitGUID and UnitGUID(unit)
	if guid and guid ~= "" then
		return guid
	end
	return Util.GetUnitFullName(unit)
end
