local _, GF = ...

-- NativeCreationGateway is the single owner of Blizzard's creation-field
-- ports. It intentionally adds no timers, event hops, field cache, or text
-- projection: callers retain their current synchronous click stack and
-- Blizzard remains the only owner of protected creation text.
GF.NativeCreationGateway = GF.NativeCreationGateway or {}
local Gateway = GF.NativeCreationGateway

local function nativeFunction(methodName)
	local api = C_LFGList
	local callback = api and api[methodName]
	return type(callback) == "function" and callback or nil
end

local function secretValue(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return not ok or secret == true
end

local function hasSafeText(value)
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok then
			return false
		end
		-- A secret string must not escape this port or be compared in Lua. Its
		-- presence is enough for Blizzard's synchronous submit validation.
		if secret == true then
			return true
		end
	end
	if value == nil then
		return false
	end
	if type(value) ~= "string" then
		return false
	end
	local ok, sanitized = pcall(string.match, value, "^%s*(.-)%s*$")
	return ok and type(sanitized) == "string" and sanitized ~= ""
end

-- Returns only a boolean; the native/protected value is neither cached nor
-- returned. The widget read preserves the existing live-validation path. When
-- it is readable but blank, Blizzard's sanitizer gets the final say (notably
-- for protected prebuilt titles).
function Gateway:HasSafeCreationName(editBox)
	if editBox ~= nil then
		local countReader = editBox.GetNumLetters
		if type(countReader) == "function" then
			local ok, count = pcall(countReader, editBox)
			if not ok or secretValue(count) or type(count) ~= "number" then
				return false
			end
			if count > 0 then
				return true
			end
		else
			-- Older/fake edit boxes may lack GetNumLetters. Keep GetText as the
			-- final fallback and reduce the value inside this port immediately.
			local reader = editBox.GetText
			if type(reader) ~= "function" then
				return false
			end
			local ok, value = pcall(reader, editBox)
			if not ok then
				return false
			end
			if hasSafeText(value) then
				return true
			end
		end
	end

	local root = LFGListFrame
	local creation = root and root.EntryCreation
	local sanitizer = LFGListEntryCreation_GetSanitizedName
	if creation == nil or type(sanitizer) ~= "function" then
		return false
	end
	local ok, value = pcall(sanitizer, creation)
	return ok and hasSafeText(value) or false
end

function Gateway:CanReadActivityInfo()
	return nativeFunction("GetActivityInfoTable") ~= nil
end

function Gateway:GetActivityInfoTable(...)
	local reader = nativeFunction("GetActivityInfoTable")
	if reader == nil then
		return nil
	end
	return reader(...)
end

function Gateway:CanReadCategoryInfo()
	return nativeFunction("GetLfgCategoryInfo") ~= nil
end

function Gateway:GetLfgCategoryInfo(...)
	local reader = nativeFunction("GetLfgCategoryInfo")
	if reader == nil then
		return nil
	end
	return reader(...)
end

function Gateway:CanClearCreationTextFields()
	return nativeFunction("ClearCreationTextFields") ~= nil
end

function Gateway:ClearCreationTextFields()
	local clear = nativeFunction("ClearCreationTextFields")
	if clear == nil then
		return false
	end
	clear()
	return true
end

function Gateway:CanCopyActiveEntryInfoToCreationFields()
	return nativeFunction("CopyActiveEntryInfoToCreationFields") ~= nil
end

function Gateway:CopyActiveEntryInfoToCreationFields()
	local copy = nativeFunction("CopyActiveEntryInfoToCreationFields")
	if copy == nil then
		return false
	end
	copy()
	return true
end

function Gateway:DoesEntryTitleMatchPrebuiltTitle(...)
	local predicate = nativeFunction("DoesEntryTitleMatchPrebuiltTitle")
	if predicate == nil then
		return nil
	end
	local result = predicate(...)
	if secretValue(result) then
		return nil
	end
	return result
end
