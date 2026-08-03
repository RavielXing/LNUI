local _, GF = ...

local Compat = GF.Compat or {}
GF.Compat = Compat

GF.INTERFACE_MIDNIGHT_12_0_0 = 120000
GF.INTERFACE_MIDNIGHT_12_0_1 = 120001
GF.INTERFACE_MIDNIGHT_12_0_5 = 120005
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

function Compat.HasAPI(owner, methodName)
	return type(owner) == "table" and type(owner[methodName]) == "function"
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
