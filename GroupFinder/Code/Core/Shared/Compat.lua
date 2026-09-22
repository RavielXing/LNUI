local _, GF = ...

local Compat = GF.Compat or {}
GF.Compat = Compat

GF.INTERFACE_MIDNIGHT_12_0_0 = 120000
GF.INTERFACE_MIDNIGHT_12_0_7 = 120007
GF.INTERFACE_MIDNIGHT_12_1_0 = 120100

local function readBuildInfo()
	if type(GetBuildInfo) ~= "function" then
		return nil, nil, nil, nil
	end

	local version, build, date, interfaceVersion = GetBuildInfo()
	return version, build, date, tonumber(interfaceVersion)
end

local version, build, buildDate, interfaceVersion = readBuildInfo()

Compat.version = version
Compat.build = build
Compat.buildDate = buildDate
Compat.interface = interfaceVersion or 0
Compat.isMidnight = Compat.interface >= GF.INTERFACE_MIDNIGHT_12_0_0
Compat.isMidnight1207OrNewer = Compat.interface >= GF.INTERFACE_MIDNIGHT_12_0_7
Compat.isMidnight121OrNewer = Compat.interface >= GF.INTERFACE_MIDNIGHT_12_1_0

function Compat.IsInterfaceAtLeast(interfaceTarget)
	interfaceTarget = tonumber(interfaceTarget)
	return interfaceTarget ~= nil and Compat.interface >= interfaceTarget
end

function Compat.GetClientExpansionLevel()
	-- Glue display state can lag behind the installed client. Use the same
	-- build-to-expansion mapping as the Encounter Journal catalog first.
	if Compat.interface >= 10000 then
		return math.floor(Compat.interface / 10000) - 1
	end
	if type(GetClientDisplayExpansionLevel) ~= "function" then return nil end
	local ok, expansion = pcall(GetClientDisplayExpansionLevel)
	if ok and type(expansion) == "number" and expansion >= 0 and expansion % 1 == 0 then
		return expansion
	end
	return nil
end

function Compat.GetAddOnLoadState(name)
	if type(name) ~= "string" or name == "" then
		return nil, nil, "invalid-name"
	end
	local checker = C_AddOns and C_AddOns.IsAddOnLoaded
	if type(checker) ~= "function" then
		return nil, nil, "checker-unavailable"
	end
	local ok, loadedOrLoading, loaded = pcall(checker, name)
	if not ok then
		return nil, nil, "check-error"
	end
	return loadedOrLoading == true, loaded == true, nil
end

function Compat.IsAddOnFullyLoaded(name)
	local _, loaded = Compat.GetAddOnLoadState(name)
	return loaded == true
end

function Compat.LoadAddOn(name)
	if type(name) ~= "string" or name == "" then
		return false, "invalid-name"
	end
	local _, alreadyLoaded = Compat.GetAddOnLoadState(name)
	if alreadyLoaded == true then
		return true
	end
	local loader = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
	if type(loader) ~= "function" then
		return false, "loader-unavailable"
	end
	local callOK, loaded, loadReason = pcall(loader, name)
	if not callOK then
		return false, "load-error"
	end
	if loaded ~= true then
		return false, loadReason or "load-rejected"
	end
	local _, fullyLoaded, checkReason = Compat.GetAddOnLoadState(name)
	if checkReason == "checker-unavailable" then
		-- Legacy clients without a state reader can only use LoadAddOn's result.
		return true
	end
	if fullyLoaded ~= true then
		return false, checkReason or "not-fully-loaded"
	end
	return true
end

local function callableTable(value)
	if type(value) ~= "table" then
		return false
	end
	local meta = getmetatable(value)
	return type(meta) == "table" and type(meta.__call) == "function"
end

function Compat.GetOptionalLibrary(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end

	local stub = _G.LibStub
	if type(stub) == "table" and type(stub.GetLibrary) == "function" then
		local ok, library = pcall(stub.GetLibrary, stub, name, true)
		return ok and library or nil
	end

	if type(stub) ~= "function" and not callableTable(stub) then
		return nil
	end
	local ok, library = pcall(function()
		return stub(name, true)
	end)
	return ok and library or nil
end

GF.GetOptionalLibrary = Compat.GetOptionalLibrary

-- Midnight 12.1 may return ordinary-looking Lua values that are marked secret
-- while chat-messaging lockdown is active.  pcall alone is insufficient:
-- tonumber(secretNumber) may succeed and still return a secret number, which
-- then faults on comparison or arithmetic.  Keep every inspectable projection
-- behind one compatibility boundary and only publish values the caller may use.
function Compat.IsAccessibleValue(value)
	-- The generated FrameScript docs mark this argument non-nil.  type() is
	-- safe for secret values and lets missing fields short-circuit first.
	if type(value) == "nil" then
		return true
	end
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret == true then
			return false
		end
	end
	return true
end

function Compat.IsAccessibleTable(value)
	if type(value) ~= "table" then
		return false
	end
	if not Compat.IsAccessibleValue(value) then
		return false
	end
	if type(canaccesstable) == "function" then
		local ok, accessible = pcall(canaccesstable, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	-- Do not reject issecrettable(value) here: partially-secret API records
	-- intentionally expose NeverSecret fields. canaccesstable authorizes the
	-- index operation; issecretvaluekey below decides each individual field.
	return true
end

function Compat.ReadAccessibleField(owner, key)
	if not Compat.IsAccessibleTable(owner) then
		return nil, "unavailable"
	end
	if type(issecretvaluekey) == "function" then
		local ok, secret = pcall(issecretvaluekey, owner, key)
		if not ok then
			return nil, "error"
		end
		if secret == true then
			return nil, "secret"
		end
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	if not ok then
		return nil, "error"
	end
	if not Compat.IsAccessibleValue(value) then
		return nil, "secret"
	end
	if type(value) == "nil" then
		return nil, "missing"
	end
	return value, "value"
end

function Compat.ToAccessibleNumber(value)
	if type(value) == "nil" then
		return nil
	end
	if not Compat.IsAccessibleValue(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	if not ok or not Compat.IsAccessibleValue(number)
		or type(number) ~= "number"
	then
		return nil
	end
	return number
end

function Compat.GetAccessibleArrayLength(values)
	if not Compat.IsAccessibleTable(values) then
		return nil
	end
	local ok, length = pcall(function()
		return #values
	end)
	if not ok then
		return nil
	end
	return Compat.ToAccessibleNumber(length)
end
