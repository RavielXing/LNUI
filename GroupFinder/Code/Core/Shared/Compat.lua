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
